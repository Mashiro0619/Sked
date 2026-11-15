"""Read a frozen Office package and publish its original embedded images."""

from datetime import date, datetime, time, timedelta
import hashlib
import json
from pathlib import Path, PurePosixPath
import posixpath
import sys
from zipfile import ZipFile

from lxml import etree
from sked_runtime import output_dir, publish


W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
A = "http://schemas.openxmlformats.org/drawingml/2006/main"
R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
M = "http://schemas.openxmlformats.org/officeDocument/2006/math"
C = "http://schemas.openxmlformats.org/drawingml/2006/chart"
TEXT_TAGS = {f"{{{namespace}}}t" for namespace in (W, A, M)} | {f"{{{W}}}delText"}


def xml_text(element):
    parts = []
    for node in element.iter():
        if node.tag in TEXT_TAGS:
            parts.append(node.text or "")
        elif node.tag == f"{{{W}}}tab":
            parts.append("\t")
        elif node.tag in (f"{{{W}}}br", f"{{{W}}}cr", f"{{{A}}}br"):
            parts.append("\n")
    return "".join(parts)


class Package:
    def __init__(self, path):
        self.archive = ZipFile(path)
        self.types = {}
        self.extensions = {}
        for item in self.xml("[Content_Types].xml"):
            if "PartName" in item.attrib:
                self.types[item.attrib["PartName"].lstrip("/")] = item.attrib["ContentType"]
            else:
                self.extensions[item.attrib["Extension"].lower()] = item.attrib["ContentType"]
        self.relationships = {}
        for name in self.archive.namelist():
            if not name.endswith(".rels"):
                continue
            parent, filename = posixpath.split(name)
            source = posixpath.join(posixpath.dirname(parent), filename[:-5])
            if name == "_rels/.rels":
                source = ""
            entries = {}
            for relation in self.xml(name):
                target = relation.attrib["Target"]
                external = relation.attrib.get("TargetMode") == "External"
                entries[relation.attrib["Id"]] = {
                    "target": target if external else posixpath.normpath(
                        posixpath.join(posixpath.dirname(source), target)
                    ).lstrip("/"),
                    "external": external,
                    "type": relation.attrib["Type"].rsplit("/", 1)[-1],
                }
            self.relationships[source] = entries

    def xml(self, name):
        return etree.fromstring(
            self.archive.read(name),
            parser=etree.XMLParser(resolve_entities=False, no_network=True),
        )

    def references(self, element, source):
        ids = {
            value
            for node in element.iter()
            for key, value in node.attrib.items()
            if key in (f"{{{R}}}embed", f"{{{R}}}link", f"{{{R}}}id")
        }
        relations = self.relationships.get(source, {})
        return [
            {"relationshipId": key, **relations[key]}
            for key in sorted(ids)
            if key in relations
        ]

    def images(self):
        result = []
        for name in self.archive.namelist():
            media_type = self.types.get(name) or self.extensions.get(
                PurePosixPath(name).suffix.lstrip(".").lower(), ""
            )
            if not media_type.startswith("image/"):
                continue
            data = self.archive.read(name)
            digest = hashlib.sha256(data).hexdigest()
            target = Path(output_dir) / f"{len(result) + 1}-{PurePosixPath(name).name}"
            target.write_bytes(data)
            location = publish(target, name=target.name, media_type=media_type)
            result.append({
                "part": name,
                "mediaType": media_type,
                "byteLength": len(data),
                "sha256": digest,
                "path": location,
                "references": [
                    {"part": source, "relationshipId": key}
                    for source, relations in self.relationships.items()
                    for key, relation in relations.items()
                    if not relation["external"] and relation["target"] == name
                ],
            })
        return result

    def text_parts(self, prefix):
        result = []
        for name in self.archive.namelist():
            if not name.startswith(prefix) or not name.endswith(".xml"):
                continue
            root = self.xml(name)
            tree = root.getroottree()
            text = []
            for node in root.iter():
                if node.tag not in TEXT_TAGS or node.text is None:
                    continue
                entry = {"location": tree.getpath(node), "text": node.text}
                for ancestor in node.iterancestors():
                    if ancestor.tag in (f"{{{W}}}ins", f"{{{W}}}del"):
                        entry["revision"] = "insertion" if ancestor.tag == f"{{{W}}}ins" else "deletion"
                        break
                text.append(entry)
            if text:
                result.append({"part": name, "text": text})
        return result

    def charts(self):
        result = []
        for name in self.archive.namelist():
            if "/charts/" not in name or not name.endswith(".xml"):
                continue
            root = self.xml(name)
            if root.tag != f"{{{C}}}chartSpace":
                continue
            tree = root.getroottree()
            result.append({
                "part": name,
                "values": [
                    {"location": tree.getpath(node), "value": node.text}
                    for node in root.iter()
                    if node.tag in (f"{{{C}}}v", f"{{{C}}}f", f"{{{A}}}t")
                    and node.text is not None
                ],
                "references": self.references(root, name),
            })
        return result


def word_blocks(element, package, source):
    blocks = []
    for child in element:
        if child.tag == f"{{{W}}}p":
            style = child.find(f"{{{W}}}pPr/{{{W}}}pStyle")
            blocks.append({
                "type": "paragraph",
                "text": xml_text(child),
                "style": None if style is None else style.get(f"{{{W}}}val"),
                "references": package.references(child, source),
            })
        elif child.tag == f"{{{W}}}tbl":
            blocks.append({
                "type": "table",
                "rows": [
                    [
                        {
                            "blocks": word_blocks(cell, package, source),
                            "properties": {
                                etree.QName(prop).localname: dict(prop.attrib)
                                for properties in cell.findall(f"{{{W}}}tcPr")
                                for prop in properties
                            },
                        }
                        for cell in row if cell.tag == f"{{{W}}}tc"
                    ]
                    for row in child if row.tag == f"{{{W}}}tr"
                ],
            })
        else:
            # Content controls, revisions and custom XML retain their document order.
            blocks.extend(word_blocks(child, package, source))
    return blocks


def inspect_docx(path, package):
    from docx import Document

    document = Document(path)
    main_part = str(document.part.partname).lstrip("/")
    sections = []
    headers = {}
    footers = {}
    for section in document.sections:
        for tag, destinations in (("headerReference", headers), ("footerReference", footers)):
            for reference in section._sectPr.findall(f"{{{W}}}{tag}"):
                relation = package.relationships[main_part][reference.get(f"{{{R}}}id")]
                destinations[reference.get(f"{{{W}}}type")] = relation["target"]
        sections.append({
            "headers": dict(headers),
            "footers": dict(footers),
        })
    return {
        "body": word_blocks(document.element.body, package, main_part),
        "sections": sections,
        "otherParts": [
            {"part": name, "blocks": word_blocks(package.xml(name), package, name)}
            for name in package.archive.namelist()
            if name.startswith("word/") and name.endswith(".xml") and name != main_part
            and PurePosixPath(name).name.startswith(("header", "footer", "footnotes", "endnotes", "comments"))
        ],
        "xmlText": package.text_parts("word/"),
    }


def cell_value(value):
    if isinstance(value, (datetime, date, time)):
        return {"type": type(value).__name__, "value": value.isoformat()}
    if isinstance(value, timedelta):
        return {"type": "duration", "seconds": value.total_seconds()}
    return value


def inspect_xlsx(path, package):
    from openpyxl import load_workbook
    from openpyxl.cell.cell import MergedCell

    # Frozen input files have storage names, not necessarily an .xlsx suffix.
    with open(path, "rb") as source:
        workbook = load_workbook(source, data_only=False, keep_links=True)
    with open(path, "rb") as source:
        cached = load_workbook(source, data_only=True, keep_links=True)
    try:
        sheets = []
        for sheet in workbook.worksheets:
            cells = []
            # The worksheet map contains stored cells, without walking its empty rectangle.
            for key in sorted(sheet._cells):
                cell = sheet._cells[key]
                if isinstance(cell, MergedCell):
                    continue
                item = {
                    "coordinate": cell.coordinate,
                    "type": cell.data_type,
                    "numberFormat": cell.number_format,
                }
                if cell.data_type == "f":
                    item["formula"] = cell.value if isinstance(cell.value, str) else vars(cell.value)
                    item["cachedValue"] = cell_value(cached[sheet.title][cell.coordinate].value)
                else:
                    item["value"] = cell_value(cell.value)
                if cell.hyperlink is not None:
                    item["hyperlink"] = {
                        "target": cell.hyperlink.target,
                        "location": cell.hyperlink.location,
                    }
                if cell.comment is not None:
                    item["comment"] = {"author": cell.comment.author, "text": cell.comment.text}
                cells.append(item)
            sheets.append({
                "name": sheet.title,
                "state": sheet.sheet_state,
                "cells": cells,
                "mergedRanges": [str(value) for value in sheet.merged_cells.ranges],
                "tables": [
                    {"name": table.name, "range": table.ref}
                    for table in sheet.tables.values()
                ],
                "freezePanes": sheet.freeze_panes,
            })
        return {
            "sheetOrder": workbook.sheetnames,
            "sheets": sheets,
            "definedNames": [
                {"name": value.name, "value": value.attr_text}
                for value in workbook.defined_names.values()
            ],
            "formulaValues": "cached values saved by the document author; not recalculated",
        }
    finally:
        workbook.close()
        cached.close()


def slide_shapes(shapes, package, source):
    from pptx.enum.shapes import MSO_SHAPE_TYPE

    result = []
    for shape in shapes:
        item = {
            "id": shape.shape_id,
            "name": shape.name,
            "type": str(shape.shape_type),
            "boundsEmu": [shape.left, shape.top, shape.width, shape.height],
            "references": package.references(shape.element, source),
        }
        if shape.shape_type == MSO_SHAPE_TYPE.GROUP:
            item["shapes"] = slide_shapes(shape.shapes, package, source)
        if shape.has_text_frame:
            item["paragraphs"] = [
                {"text": paragraph.text, "level": paragraph.level}
                for paragraph in shape.text_frame.paragraphs
            ]
        if shape.has_table:
            item["table"] = [
                [
                    {
                        "text": cell.text,
                        "mergeOrigin": cell.is_merge_origin,
                        "spanned": cell.is_spanned,
                        "rowSpan": cell.span_height,
                        "columnSpan": cell.span_width,
                    }
                    for cell in row.cells
                ]
                for row in shape.table.rows
            ]
        if shape.has_chart:
            item["chartType"] = str(shape.chart.chart_type)
        result.append(item)
    return result


def inspect_pptx(path, package):
    from pptx import Presentation

    presentation = Presentation(path)
    slides = []
    for index, slide in enumerate(presentation.slides, 1):
        source = str(slide.part.partname).lstrip("/")
        item = {
            "number": index,
            "part": source,
            "shapes": slide_shapes(slide.shapes, package, source),
        }
        if slide.has_notes_slide:
            notes = slide.notes_slide
            notes_source = str(notes.part.partname).lstrip("/")
            item["notes"] = {
                "part": notes_source,
                "text": None if notes.notes_text_frame is None else notes.notes_text_frame.text,
                "shapes": slide_shapes(notes.shapes, package, notes_source),
            }
        slides.append(item)
    return {
        "sizeEmu": [presentation.slide_width, presentation.slide_height],
        "slides": slides,
        "xmlText": package.text_parts("ppt/"),
    }


def inspect_document(path, document_format):
    readers = {"docx": inspect_docx, "xlsx": inspect_xlsx, "pptx": inspect_pptx}
    reader = readers[document_format]
    package = Package(path)
    try:
        result = {
            "format": document_format,
            "document": reader(path, package),
            "charts": package.charts(),
            "images": package.images(),
            "relationships": package.relationships,
        }
        json.dump(result, sys.stdout, ensure_ascii=False, allow_nan=False, separators=(",", ":"))
        sys.stdout.write("\n")
    finally:
        package.archive.close()


if __name__ == "__main__":
    inspect_document(sys.argv[2], sys.argv[1])
