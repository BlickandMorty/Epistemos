use std::collections::BTreeMap;

use serde_json::{json, Value};

use super::{TriFusionDocument, TriFusionError};

impl TriFusionDocument {
    pub fn parse_html(input: &str) -> Result<Self, TriFusionError> {
        parse_html_document(input)
    }

    pub fn to_html(&self) -> Result<String, TriFusionError> {
        render_html_document(self.root())
    }

    pub fn normalize_html(input: &str) -> Result<String, TriFusionError> {
        parse_html_document(input)?.to_html()
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct HtmlElement {
    name: String,
    attrs: BTreeMap<String, String>,
    children: Vec<HtmlChild>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum HtmlChild {
    Element(HtmlElement),
    Text(String),
}

struct HtmlParser<'a> {
    input: &'a str,
    offset: usize,
}

fn parse_html_document(input: &str) -> Result<TriFusionDocument, TriFusionError> {
    let mut parser = HtmlParser { input, offset: 0 };
    let children = parser.parse_top_level_children()?;
    parser.skip_whitespace();
    if !parser.is_eof() {
        return Err(invalid_html("trailing HTML after document body"));
    }

    let elements = unwrap_document_wrapper(children)?;
    let mut content = Vec::with_capacity(elements.len());
    for (index, element) in elements.iter().enumerate() {
        content.push(block_from_html_element(
            element,
            &format!("html.children[{index}]"),
        )?);
    }

    TriFusionDocument::from_json_value(json!({
        "type": "doc",
        "content": content,
    }))
}

fn render_html_document(root: &Value) -> Result<String, TriFusionError> {
    let content = root
        .as_object()
        .and_then(|object| object.get("content"))
        .and_then(Value::as_array)
        .ok_or_else(|| unsupported("$", "document root must have array content"))?;

    let mut blocks = Vec::with_capacity(content.len());
    for (index, node) in content.iter().enumerate() {
        blocks.push(render_html_block(node, &format!("$.content[{index}]"))?);
    }
    Ok(blocks.join(""))
}

impl<'a> HtmlParser<'a> {
    fn parse_top_level_children(&mut self) -> Result<Vec<HtmlChild>, TriFusionError> {
        let mut children = Vec::new();
        while !self.is_eof() {
            if self.starts_with("</") {
                return Err(invalid_html("unexpected closing tag at document root"));
            }
            if self.starts_with("<") {
                children.push(HtmlChild::Element(self.parse_element()?));
            } else {
                let text = self.parse_text()?;
                if !text.trim().is_empty() {
                    return Err(invalid_html("text outside a block element is unsupported"));
                }
                children.push(HtmlChild::Text(text));
            }
        }
        Ok(children)
    }

    fn parse_element(&mut self) -> Result<HtmlElement, TriFusionError> {
        self.expect("<")?;
        if self.starts_with("/") {
            return Err(invalid_html("unexpected closing tag"));
        }

        let name = self.parse_name()?.to_ascii_lowercase();
        if name == "script" || name == "style" {
            return Err(invalid_html(
                "unsafe HTML tag is outside the canonical subset",
            ));
        }

        let attrs = self.parse_attrs()?;
        self.expect(">")?;

        let mut children = Vec::new();
        loop {
            if self.is_eof() {
                return Err(invalid_html(format!("unclosed <{name}> tag")));
            }
            if self.starts_with("</") {
                self.expect("</")?;
                let closing = self.parse_name()?.to_ascii_lowercase();
                self.skip_whitespace();
                self.expect(">")?;
                if closing != name {
                    return Err(invalid_html(format!(
                        "closing tag </{closing}> does not match <{name}>"
                    )));
                }
                break;
            }
            if self.starts_with("<") {
                children.push(HtmlChild::Element(self.parse_element()?));
            } else {
                children.push(HtmlChild::Text(self.parse_text()?));
            }
        }

        Ok(HtmlElement {
            name,
            attrs,
            children,
        })
    }

    fn parse_attrs(&mut self) -> Result<BTreeMap<String, String>, TriFusionError> {
        let mut attrs = BTreeMap::new();
        loop {
            self.skip_whitespace();
            if self.starts_with(">") {
                break;
            }
            if self.starts_with("/>") {
                return Err(invalid_html(
                    "self-closing tags are outside the canonical subset",
                ));
            }

            let name = self.parse_attr_name()?.to_ascii_lowercase();
            self.skip_whitespace();
            let value = if self.starts_with("=") {
                self.offset += 1;
                self.skip_whitespace();
                self.parse_quoted_attr_value()?
            } else {
                String::new()
            };

            if attrs.insert(name.clone(), value).is_some() {
                return Err(invalid_html(format!("duplicate attribute {name:?}")));
            }
        }
        Ok(attrs)
    }

    fn parse_name(&mut self) -> Result<String, TriFusionError> {
        let start = self.offset;
        while let Some(ch) = self.peek_char() {
            if ch.is_ascii_alphanumeric() || ch == '-' {
                self.offset += ch.len_utf8();
            } else {
                break;
            }
        }
        if self.offset == start {
            return Err(invalid_html("expected HTML tag name"));
        }
        Ok(self.input[start..self.offset].to_string())
    }

    fn parse_attr_name(&mut self) -> Result<String, TriFusionError> {
        let start = self.offset;
        while let Some(ch) = self.peek_char() {
            if ch.is_ascii_alphanumeric() || ch == '-' || ch == '_' || ch == ':' {
                self.offset += ch.len_utf8();
            } else {
                break;
            }
        }
        if self.offset == start {
            return Err(invalid_html("expected HTML attribute name"));
        }
        Ok(self.input[start..self.offset].to_string())
    }

    fn parse_quoted_attr_value(&mut self) -> Result<String, TriFusionError> {
        let Some(quote) = self.peek_char() else {
            return Err(invalid_html("expected quoted HTML attribute value"));
        };
        if quote != '"' && quote != '\'' {
            return Err(invalid_html("HTML attribute values must be quoted"));
        }
        self.offset += quote.len_utf8();
        let start = self.offset;
        while let Some(ch) = self.peek_char() {
            if ch == quote {
                let raw = &self.input[start..self.offset];
                self.offset += quote.len_utf8();
                return decode_html_entities(raw);
            }
            self.offset += ch.len_utf8();
        }
        Err(invalid_html("unclosed HTML attribute value"))
    }

    fn parse_text(&mut self) -> Result<String, TriFusionError> {
        let start = self.offset;
        while !self.is_eof() && !self.starts_with("<") {
            let ch = self.peek_char().expect("not eof");
            self.offset += ch.len_utf8();
        }
        decode_html_entities(&self.input[start..self.offset])
    }

    fn skip_whitespace(&mut self) {
        while let Some(ch) = self.peek_char() {
            if ch.is_whitespace() {
                self.offset += ch.len_utf8();
            } else {
                break;
            }
        }
    }

    fn starts_with(&self, needle: &str) -> bool {
        self.input[self.offset..].starts_with(needle)
    }

    fn expect(&mut self, token: &str) -> Result<(), TriFusionError> {
        if !self.starts_with(token) {
            return Err(invalid_html(format!("expected {token:?}")));
        }
        self.offset += token.len();
        Ok(())
    }

    fn peek_char(&self) -> Option<char> {
        self.input[self.offset..].chars().next()
    }

    fn is_eof(&self) -> bool {
        self.offset >= self.input.len()
    }
}

fn unwrap_document_wrapper(children: Vec<HtmlChild>) -> Result<Vec<HtmlElement>, TriFusionError> {
    let elements = element_children_only(&children, "html")?;
    if elements.len() == 1 {
        let wrapper = &elements[0];
        if (wrapper.name == "div" || wrapper.name == "section") && is_document_wrapper(wrapper) {
            return element_children_only(&wrapper.children, "html.wrapper");
        }
    }
    Ok(elements)
}

fn is_document_wrapper(element: &HtmlElement) -> bool {
    if element.attrs.is_empty() {
        return true;
    }
    element.attrs.len() == 1 && element.attrs.contains_key("data-tri-fusion-doc")
}

fn block_from_html_element(element: &HtmlElement, path: &str) -> Result<Value, TriFusionError> {
    match element.name.as_str() {
        "p" => {
            reject_attrs(element, path, &[])?;
            Ok(paragraph_node(text_children_only(element, path)?))
        }
        "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => {
            reject_attrs(element, path, &[])?;
            let level = element.name[1..].parse::<u64>().expect("heading level");
            Ok(json!({
                "type": "heading",
                "attrs": {
                    "level": level,
                },
                "content": [text_node(text_children_only(element, path)?)],
            }))
        }
        "pre" => code_block_from_html(element, path),
        "blockquote" => blockquote_from_html(element, path),
        "ul" => bullet_list_from_html(element, path),
        kind => Err(invalid_html(format!(
            "HTML tag <{kind}> is outside the canonical subset"
        ))),
    }
}

fn code_block_from_html(element: &HtmlElement, path: &str) -> Result<Value, TriFusionError> {
    reject_attrs(element, path, &[])?;
    let code_children = element_children_only(&element.children, path)?;
    if code_children.len() != 1 || code_children[0].name != "code" {
        return Err(invalid_html(
            "code block must be <pre><code>...</code></pre>",
        ));
    }
    let code = &code_children[0];
    reject_attrs(code, &format!("{path}.code"), &["class"])?;

    let mut attrs = serde_json::Map::new();
    if let Some(class) = code.attrs.get("class") {
        let mut language = None;
        for token in class.split_whitespace() {
            if let Some(value) = token.strip_prefix("language-") {
                if language.replace(value).is_some() {
                    return Err(invalid_html("code block has multiple language classes"));
                }
            }
        }
        if let Some(language) = language {
            if language.is_empty() {
                return Err(invalid_html("code block language class is empty"));
            }
            attrs.insert("language".to_string(), Value::String(language.to_string()));
        }
    }

    Ok(json!({
        "type": "codeBlock",
        "attrs": attrs,
        "content": [text_node(text_children_only(code, &format!("{path}.code"))?)],
    }))
}

fn blockquote_from_html(element: &HtmlElement, path: &str) -> Result<Value, TriFusionError> {
    reject_attrs(element, path, &[])?;
    let children = element_children_only(&element.children, path)?;
    if children.len() != 1 || children[0].name != "p" {
        return Err(invalid_html(
            "blockquote must contain exactly one paragraph",
        ));
    }
    let paragraph = &children[0];
    reject_attrs(paragraph, &format!("{path}.p"), &[])?;
    Ok(json!({
        "type": "blockquote",
        "content": [paragraph_node(text_children_only(paragraph, &format!("{path}.p"))?)],
    }))
}

fn bullet_list_from_html(element: &HtmlElement, path: &str) -> Result<Value, TriFusionError> {
    reject_attrs(element, path, &[])?;
    let items = element_children_only(&element.children, path)?;
    if items.is_empty() {
        return Err(invalid_html("bullet list must contain at least one item"));
    }

    let mut item_values = Vec::with_capacity(items.len());
    for (index, item) in items.iter().enumerate() {
        if item.name != "li" {
            return Err(invalid_html("bullet list children must be <li> elements"));
        }
        reject_attrs(item, &format!("{path}.li[{index}]"), &[])?;
        let item_path = format!("{path}.li[{index}]");
        let has_element_children = item
            .children
            .iter()
            .any(|child| matches!(child, HtmlChild::Element(_)));
        let paragraph = if has_element_children {
            let item_children = element_children_only(&item.children, &item_path)?;
            match item_children.as_slice() {
                [paragraph] if paragraph.name == "p" => {
                    paragraph_node(text_children_only(paragraph, &format!("{item_path}.p"))?)
                }
                _ => return Err(invalid_html("list item must contain text or one paragraph")),
            }
        } else {
            paragraph_node(text_children_only(item, &item_path)?)
        };
        item_values.push(json!({
            "type": "listItem",
            "content": [paragraph],
        }));
    }

    Ok(json!({
        "type": "bulletList",
        "content": item_values,
    }))
}

fn element_children_only(
    children: &[HtmlChild],
    path: &str,
) -> Result<Vec<HtmlElement>, TriFusionError> {
    let mut elements = Vec::new();
    for child in children {
        match child {
            HtmlChild::Element(element) => elements.push(element.clone()),
            HtmlChild::Text(text) if text.trim().is_empty() => {}
            HtmlChild::Text(_) => {
                return Err(invalid_html(format!(
                    "{path} contains text where only elements are supported"
                )));
            }
        }
    }
    Ok(elements)
}

fn text_children_only(element: &HtmlElement, path: &str) -> Result<String, TriFusionError> {
    let mut text = String::new();
    for child in &element.children {
        match child {
            HtmlChild::Text(value) => text.push_str(value),
            HtmlChild::Element(child) => {
                return Err(invalid_html(format!(
                    "{path} contains unsupported child <{}>",
                    child.name
                )));
            }
        }
    }
    Ok(text)
}

fn reject_attrs(element: &HtmlElement, path: &str, allowed: &[&str]) -> Result<(), TriFusionError> {
    for attr in element.attrs.keys() {
        if !allowed.iter().any(|allowed| allowed == attr) {
            return Err(invalid_html(format!(
                "{path} carries unsupported attribute {attr:?}"
            )));
        }
    }
    Ok(())
}

fn render_html_block(node: &Value, path: &str) -> Result<String, TriFusionError> {
    match node_type(node, path)? {
        "paragraph" => Ok(format!(
            "<p>{}</p>",
            escape_html_text(&plain_text(node, path)?)
        )),
        "heading" => render_heading(node, path),
        "codeBlock" => render_code_block(node, path),
        "blockquote" => render_blockquote(node, path),
        "bulletList" => render_bullet_list(node, path),
        kind => Err(unsupported(
            path,
            &format!("node type {kind:?} has no canonical HTML spelling yet"),
        )),
    }
}

fn render_heading(node: &Value, path: &str) -> Result<String, TriFusionError> {
    let level = node
        .get("attrs")
        .and_then(Value::as_object)
        .and_then(|attrs| attrs.get("level"))
        .and_then(Value::as_u64)
        .ok_or_else(|| unsupported(path, "heading requires attrs.level"))?;
    if !(1..=6).contains(&level) {
        return Err(unsupported(path, "heading level must be between 1 and 6"));
    }
    Ok(format!(
        "<h{level}>{}</h{level}>",
        escape_html_text(&plain_text(node, path)?)
    ))
}

fn render_code_block(node: &Value, path: &str) -> Result<String, TriFusionError> {
    let language = node
        .get("attrs")
        .and_then(Value::as_object)
        .and_then(|attrs| attrs.get("language"))
        .and_then(Value::as_str)
        .unwrap_or("");
    let language_attr = if language.is_empty() {
        String::new()
    } else if language.split_whitespace().count() == 1 && !language.contains('"') {
        format!(" class=\"language-{}\"", escape_html_attr(language))
    } else {
        return Err(unsupported(path, "code block language must be one token"));
    };
    Ok(format!(
        "<pre><code{language_attr}>{}</code></pre>",
        escape_html_text(&plain_text(node, path)?)
    ))
}

fn render_blockquote(node: &Value, path: &str) -> Result<String, TriFusionError> {
    let children = node_children(node, path)?;
    if children.len() != 1 {
        return Err(unsupported(
            path,
            "blockquote must contain exactly one paragraph",
        ));
    }
    let child_path = format!("{path}.content[0]");
    if node_type(&children[0], &child_path)? != "paragraph" {
        return Err(unsupported(path, "blockquote child must be paragraph"));
    }
    Ok(format!(
        "<blockquote><p>{}</p></blockquote>",
        escape_html_text(&plain_text(&children[0], &child_path)?)
    ))
}

fn render_bullet_list(node: &Value, path: &str) -> Result<String, TriFusionError> {
    let children = node_children(node, path)?;
    if children.is_empty() {
        return Err(unsupported(
            path,
            "bullet list must contain at least one item",
        ));
    }
    let mut html = String::from("<ul>");
    for (index, child) in children.iter().enumerate() {
        let item_path = format!("{path}.content[{index}]");
        if node_type(child, &item_path)? != "listItem" {
            return Err(unsupported(
                &item_path,
                "bullet list child must be listItem",
            ));
        }
        let item_children = node_children(child, &item_path)?;
        if item_children.len() != 1 {
            return Err(unsupported(
                &item_path,
                "list item must contain one paragraph",
            ));
        }
        let paragraph_path = format!("{item_path}.content[0]");
        if node_type(&item_children[0], &paragraph_path)? != "paragraph" {
            return Err(unsupported(
                &paragraph_path,
                "list item child must be paragraph",
            ));
        }
        html.push_str("<li><p>");
        html.push_str(&escape_html_text(&plain_text(
            &item_children[0],
            &paragraph_path,
        )?));
        html.push_str("</p></li>");
    }
    html.push_str("</ul>");
    Ok(html)
}

fn node_children(node: &Value, path: &str) -> Result<Vec<Value>, TriFusionError> {
    node.get("content")
        .and_then(Value::as_array)
        .cloned()
        .ok_or_else(|| unsupported(path, "node must have array content"))
}

fn node_type<'a>(node: &'a Value, path: &str) -> Result<&'a str, TriFusionError> {
    node.as_object()
        .and_then(|object| object.get("type"))
        .and_then(Value::as_str)
        .ok_or_else(|| unsupported(path, "node must have string type"))
}

fn plain_text(node: &Value, path: &str) -> Result<String, TriFusionError> {
    let mut text = String::new();
    for (index, child) in node_children(node, path)?.iter().enumerate() {
        let child_path = format!("{path}.content[{index}]");
        let object = child
            .as_object()
            .ok_or_else(|| unsupported(&child_path, "inline child must be object"))?;
        if object.get("type").and_then(Value::as_str) != Some("text") {
            return Err(unsupported(
                &child_path,
                "only text inline children are supported",
            ));
        }
        if object.get("marks").is_some() {
            return Err(unsupported(
                &child_path,
                "marked text is outside the HTML subset",
            ));
        }
        let value = object
            .get("text")
            .and_then(Value::as_str)
            .ok_or_else(|| unsupported(&child_path, "text node must have string text"))?;
        text.push_str(value);
    }
    Ok(text)
}

fn paragraph_node(text: impl Into<String>) -> Value {
    json!({
        "type": "paragraph",
        "content": [text_node(text)],
    })
}

fn text_node(text: impl Into<String>) -> Value {
    json!({
        "type": "text",
        "text": text.into(),
    })
}

fn decode_html_entities(raw: &str) -> Result<String, TriFusionError> {
    let mut decoded = String::with_capacity(raw.len());
    let mut rest = raw;
    while let Some(index) = rest.find('&') {
        decoded.push_str(&rest[..index]);
        let entity_start = index + 1;
        let Some(entity_end) = rest[entity_start..].find(';') else {
            return Err(invalid_html("unterminated HTML entity"));
        };
        let entity = &rest[entity_start..entity_start + entity_end];
        let value = match entity {
            "amp" => "&",
            "lt" => "<",
            "gt" => ">",
            "quot" => "\"",
            "#39" | "apos" => "'",
            _ => return Err(invalid_html(format!("unsupported HTML entity &{entity};"))),
        };
        decoded.push_str(value);
        rest = &rest[entity_start + entity_end + 1..];
    }
    decoded.push_str(rest);
    Ok(decoded)
}

fn escape_html_text(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

fn escape_html_attr(text: &str) -> String {
    escape_html_text(text).replace('\'', "&#39;")
}

fn invalid_html(message: impl Into<String>) -> TriFusionError {
    TriFusionError::InvalidHtml {
        message: message.into(),
    }
}

fn unsupported(path: &str, message: &str) -> TriFusionError {
    TriFusionError::UnsupportedHtmlProjection {
        path: path.to_string(),
        message: message.to_string(),
    }
}
