//! Anonymous web retrieval through replaceable providers and scoped tools.

mod contracts;
mod extract;
mod http;
mod service;
mod tools;

pub use contracts::{
    ExtractedWebContent, RawWebResponse, Result, WebContent, WebError, WebErrorCode,
    WebFetchRequest, WebFetchResult, WebLink, WebProvider, WebPublication, WebSource,
};
pub use http::HttpWebProvider;
pub use service::{DefaultWebPlugin, WEB_SERVICE, WebService};
pub use tools::WebToolPlugin;
