//! `web_fetch` MCP tool — fetch an HTTP/HTTPS URL and return the body as text.

use crate::shell::SharedState;
use rmcp::{model::CallToolResult, ErrorData};
use schemars::JsonSchema;
use serde::Deserialize;
use std::time::Duration;

const FETCH_TIMEOUT: Duration = Duration::from_secs(10);
const MAX_BYTES: usize = 50 * 1024;

#[derive(Debug, Deserialize, JsonSchema)]
pub struct WebFetchParams {
    /// URL to fetch (http:// or https://)
    pub url: String,
    /// Maximum response bytes to return (default 8192, cap 51200)
    #[serde(default)]
    pub max_bytes: Option<usize>,
}

pub async fn run(_state: &SharedState, p: WebFetchParams) -> Result<CallToolResult, ErrorData> {
    let url = p.url.trim();
    if !url.starts_with("http://") && !url.starts_with("https://") {
        return Err(ErrorData::invalid_params("url must be http(s)", None));
    }
    let cap = p.max_bytes.unwrap_or(8_192).min(MAX_BYTES);

    let client = reqwest::Client::builder()
        .connect_timeout(FETCH_TIMEOUT)
        .timeout(FETCH_TIMEOUT)
        .build()
        .map_err(|e| ErrorData::internal_error(format!("client init failed: {e}"), None))?;

    let resp = client
        .get(url)
        .send()
        .await
        .map_err(|e| ErrorData::internal_error(format!("fetch failed: {e}"), None))?;

    if !resp.status().is_success() {
        return Err(ErrorData::internal_error(
            format!("HTTP {} from {url}", resp.status()),
            None,
        ));
    }

    let text = resp
        .text()
        .await
        .map_err(|e| ErrorData::internal_error(format!("read body failed: {e}"), None))?;

    let out = if text.len() > cap {
        format!(
            "{}...[truncated {} bytes]",
            &text[..cap],
            text.len() - cap
        )
    } else {
        text
    };

    Ok(CallToolResult::success(vec![rmcp::model::Content::text(out)]))
}
