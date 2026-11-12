use std::collections::{BTreeMap, HashSet};

use serde_json::Value;
use sha2::{Digest, Sha256};

use super::{
    ControlledReaderRegistration, EnvironmentValue, ExecutionCapabilities, ExecutionError,
    ExecutionErrorCode, ExecutionIdentity, ExecutionProviderIdentity, ExecutionSpec,
    FrozenExecutionKind, FrozenExecutionSpec, InputSnapshot, ResourceVersion, Result,
};

pub(super) fn validate_request(
    request: &ExecutionSpec,
    capabilities: &ExecutionCapabilities,
) -> Result<()> {
    match request {
        ExecutionSpec::Python(input) => {
            if !capabilities.python {
                return Err(ExecutionError::new(
                    ExecutionErrorCode::Unsupported,
                    "This provider does not offer Python execution",
                ));
            }
            no_nul(&input.code, "Python source")?;
            validate_argv(&input.argv)?;
            validate_resource(&input.cwd)?;
            validate_variables(&input.environment)?;
            validate_inputs(&input.inputs)
        }
        ExecutionSpec::ControlledRead(input) => {
            registered_reader(&input.reader_id, capabilities)?;
            validate_json(&input.arguments)?;
            validate_inputs(&input.inputs)
        }
    }
}

pub(super) fn freeze(
    request: &ExecutionSpec,
    frozen: &mut FrozenExecutionSpec,
    provider: &ExecutionProviderIdentity,
    capabilities: &ExecutionCapabilities,
) -> Result<()> {
    validate_request(request, capabilities)?;
    validate_provider(provider)?;
    if frozen.environment.provider != *provider {
        return Err(ExecutionError::new(
            ExecutionErrorCode::IdentityMismatch,
            "The prepared environment belongs to another provider instance",
        ));
    }
    let environment = &frozen.environment;
    for value in [
        &environment.platform,
        &environment.architecture,
        &environment.interpreter,
        &environment.interpreter_version,
    ] {
        required(value, "execution environment identity")?;
    }
    for (name, version) in &environment.dependencies {
        required(name, "dependency name")?;
        required(version, "dependency version")?;
    }
    // This digest describes the actual provider build. Never replace it with
    // a hash of version labels supplied in the public environment description.
    require_digest(&environment.environment_digest)?;
    validate_argv(&frozen.argv)?;
    validate_resource(&frozen.cwd)?;
    validate_variables(&frozen.variables)?;
    validate_inputs(&frozen.inputs)?;

    // Only publish the finalized description after every comparison succeeds.
    let mut candidate = frozen.clone();
    match (request, &mut candidate.kind) {
        (ExecutionSpec::Python(input), FrozenExecutionKind::Python { code, code_digest }) => {
            if code.as_str() != input.code.as_str()
                || candidate.argv != input.argv
                || candidate.cwd_resource != input.cwd_resource
                || candidate.cwd != input.cwd
                || candidate.variables != input.environment
                || candidate.inputs != input.inputs
            {
                return Err(stale("The prepared Python material changed"));
            }
            reconcile_digest(code_digest, sha256(input.code.as_bytes()))?;
        }
        (
            ExecutionSpec::ControlledRead(input),
            FrozenExecutionKind::ControlledRead {
                reader_id,
                registration_digest,
                arguments,
                arguments_digest,
            },
        ) => {
            let registration = registered_reader(&input.reader_id, capabilities)?;
            if reader_id.as_str() != input.reader_id.as_str()
                || !registration_digest.eq_ignore_ascii_case(&registration.registration_digest)
                || *arguments != input.arguments
                || candidate.inputs != input.inputs
            {
                return Err(stale("The prepared controlled reader material changed"));
            }
            reconcile_digest(arguments_digest, json_digest(&input.arguments)?)?;
        }
        _ => return Err(stale("The prepared execution kind changed")),
    }

    let supplied_digest = std::mem::take(&mut candidate.spec_digest);
    let value = serde_json::to_value(&candidate)
        .map_err(|_| invalid("The prepared execution cannot be serialized"))?;
    let mut spec_digest = supplied_digest;
    reconcile_digest(&mut spec_digest, json_digest(&value)?)?;
    candidate.spec_digest = spec_digest;
    *frozen = candidate;
    Ok(())
}

pub(super) fn validate_identity(identity: &ExecutionIdentity) -> Result<()> {
    if !valid_identity_text(&identity.execution_id)
        || !valid_identity_text(&identity.operation_id)
        || !is_digest(&identity.spec_digest)
    {
        return Err(ExecutionError::new(
            ExecutionErrorCode::IdentityMismatch,
            "The execution identity is incomplete or malformed",
        ));
    }
    validate_provider(&identity.provider)
}

fn validate_provider(provider: &ExecutionProviderIdentity) -> Result<()> {
    if !valid_identity_text(&provider.provider_id) || !valid_identity_text(&provider.instance_id) {
        return Err(ExecutionError::new(
            ExecutionErrorCode::IdentityMismatch,
            "The execution provider identity is incomplete or malformed",
        ));
    }
    Ok(())
}

fn registered_reader<'a>(
    reader_id: &str,
    capabilities: &'a ExecutionCapabilities,
) -> Result<&'a ControlledReaderRegistration> {
    required(reader_id, "controlled reader identity")?;
    let mut matches = capabilities
        .controlled_readers
        .iter()
        .filter(|registration| registration.reader_id == reader_id);
    let registration = matches.next().ok_or_else(|| {
        ExecutionError::new(
            ExecutionErrorCode::UnknownReader,
            "The controlled reader is not registered by this provider",
        )
    })?;
    if matches.next().is_some() {
        return Err(invalid("The controlled reader registration is ambiguous"));
    }
    require_digest(&registration.registration_digest)?;
    // The provider validates its registered closed schema; this layer checks
    // the same reader identity and exact arguments again after preparation.
    Ok(registration)
}

fn validate_resource(resource: &ResourceVersion) -> Result<()> {
    required(&resource.resource_id, "resource identity")?;
    required(&resource.version, "resource revision")?;
    if let Some(digest) = &resource.digest {
        require_digest(digest)?;
    }
    Ok(())
}

fn validate_inputs(inputs: &[InputSnapshot]) -> Result<()> {
    let mut paths = HashSet::new();
    for input in inputs {
        validate_resource(&input.source)?;
        validate_resource(&input.snapshot)?;
        if input.snapshot.digest.is_none() || input.snapshot.byte_length.is_none() {
            return Err(invalid(
                "A frozen input requires its content digest and length",
            ));
        }
        required(&input.mounted_path, "mounted input path")?;
        if !paths.insert(input.mounted_path.as_str()) {
            return Err(invalid("Mounted input paths must be unique"));
        }
    }
    Ok(())
}

fn validate_argv(argv: &[String]) -> Result<()> {
    for argument in argv {
        no_nul(argument, "execution argument")?;
    }
    Ok(())
}

fn validate_variables(variables: &BTreeMap<String, EnvironmentValue>) -> Result<()> {
    for (name, value) in variables {
        required(name, "environment variable name")?;
        if name.contains('=') {
            return Err(invalid("An environment variable name cannot contain '='"));
        }
        match value {
            EnvironmentValue::Plain(value) => no_nul(value, "environment variable value")?,
            EnvironmentValue::SecretHandle { handle, revision } => {
                required(handle, "secret handle")?;
                required(revision, "secret revision")?;
            }
        }
    }
    Ok(())
}

fn validate_json(value: &Value) -> Result<()> {
    match value {
        Value::String(value) => no_nul(value, "reader argument")?,
        Value::Array(values) => {
            for value in values {
                validate_json(value)?;
            }
        }
        Value::Object(values) => {
            for (key, value) in values {
                no_nul(key, "reader argument key")?;
                validate_json(value)?;
            }
        }
        _ => {}
    }
    Ok(())
}

fn required(value: &str, field: &str) -> Result<()> {
    if value.trim().is_empty() {
        return Err(invalid(&format!("The {field} must not be empty")));
    }
    no_nul(value, field)
}

fn no_nul(value: &str, field: &str) -> Result<()> {
    if value.contains('\0') {
        return Err(invalid(&format!("The {field} cannot contain NUL")));
    }
    Ok(())
}

fn valid_identity_text(value: &str) -> bool {
    !value.trim().is_empty() && !value.contains('\0')
}

fn is_digest(value: &str) -> bool {
    value.len() == 64 && value.bytes().all(|byte| byte.is_ascii_hexdigit())
}

fn require_digest(value: &str) -> Result<()> {
    if !is_digest(value) {
        return Err(invalid("A content or environment digest must be SHA256"));
    }
    Ok(())
}

fn reconcile_digest(supplied: &mut String, computed: String) -> Result<()> {
    if !supplied.is_empty() && !supplied.eq_ignore_ascii_case(&computed) {
        return Err(stale("The prepared digest does not match its material"));
    }
    *supplied = computed;
    Ok(())
}

fn sha256(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

fn json_digest(value: &Value) -> Result<String> {
    let encoded = serde_json::to_vec(&canonical_json(value))
        .map_err(|_| invalid("The execution material cannot be serialized"))?;
    Ok(sha256(&encoded))
}

fn canonical_json(value: &Value) -> Value {
    match value {
        Value::Object(values) => {
            let sorted: BTreeMap<_, _> = values.iter().collect();
            Value::Object(
                sorted
                    .into_iter()
                    .map(|(key, value)| (key.clone(), canonical_json(value)))
                    .collect(),
            )
        }
        Value::Array(values) => Value::Array(values.iter().map(canonical_json).collect()),
        value => value.clone(),
    }
}

fn invalid(message: &str) -> ExecutionError {
    ExecutionError::new(ExecutionErrorCode::InvalidSpec, message)
}

fn stale(message: &str) -> ExecutionError {
    ExecutionError::new(ExecutionErrorCode::StaleSpec, message)
}
