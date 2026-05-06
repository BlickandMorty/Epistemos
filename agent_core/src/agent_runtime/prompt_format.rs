use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct RuntimeToolDefinition {
    pub name: String,
    pub description: String,
    pub parameters: Value,
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct RuntimePromptInput {
    pub tools: Vec<RuntimeToolDefinition>,
    pub additional_instructions: Option<String>,
    pub knowledge_index: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum RuntimeMessageRole {
    System,
    User,
    Assistant,
    Tool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RuntimeMessage {
    pub role: RuntimeMessageRole,
    pub content: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RuntimeToolResult {
    pub tool_name: String,
    pub result_json: String,
    pub is_error: bool,
}

pub fn build_system_prompt(input: &RuntimePromptInput) -> String {
    let tools_json = formatted_tools_json(&input.tools);
    let trimmed_instructions = input
        .additional_instructions
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty());

    let mut prompt = String::new();
    if let Some(knowledge_index) = input
        .knowledge_index
        .as_deref()
        .filter(|value| !value.is_empty())
    {
        prompt.push_str(knowledge_index);
        prompt.push('\n');
    }

    prompt.push_str(&format!(
        "You are a function calling AI model. You are provided with function signatures within <tools></tools> XML tags. You may call one or more functions to assist with the user query. Don't make assumptions about what values to plug into functions. After calling and executing the functions, you will be provided with function results within <tool_response></tool_response> XML tags.\n\
<tools>\n\
{tools_json}\n\
</tools>\n\
For each function call, return a JSON object with function name and arguments within <tool_call></tool_call> XML tags.\n\
<tool_call>\n\
{{\"name\": <function-name>, \"arguments\": <args-dict>}}\n\
</tool_call>\n\
Keep hidden reasoning inside <think></think> tags. If the model falls back to legacy formatting, <scratch_pad></scratch_pad> is also allowed. Never place raw reasoning or analysis notes outside those hidden tags.\n\
Use tools only for missing context or explicit external side effects. Do not route already-available local substrate answers through tools.\n\
Keep deterministic local substrate answers on the direct path; do not add a gateway hop when no external context is needed.\n\
Return external evidence as structured artifacts and provenance, not graph authority."
    ));

    prompt.push_str(
        "\n\nIf the answer is already in the conversation context, attached note text, or other provided material, answer directly without calling a tool.\n\
After receiving a <tool_response>, summarize it for the user unless the response clearly says it failed or more information is still required.\n\
Never repeat the same tool call when the previous <tool_response> already gave you the needed information.\n\
For vault notes, never guess a filesystem path from a title. Use vault_search first and then vault_read with the returned vault-relative path.\n\
For vault note creation or updates, use vault_write with a human-readable vault-relative .md path and the full markdown content.\n\
If the user gives a note title but not a path, choose a vault-relative .md path that matches the requested title.\n\
If asked to create or update a note and then read it back, call vault_write first and then vault_read on that same exact note path.\n\
Do not claim a note was created, updated, or read back before the required <tool_response> confirms the operation succeeded.\n\
File tools can use the exact filesystem path the user provided, including absolute paths and ~/ home expansion, or a vault-relative path inside the active managed runtime vault (or ScratchVault when no vault is attached).\n\
Do not invent alternate paths, filenames, or directories.\n\
Use the exact path the user provided instead of rewriting it to tmp/example.txt or guessing a nearby path.\n\
If asked to write a file and then read it back, call write_file first and then read_file on that same exact path.\n\
Do not answer an explicit file read/write request from the requested contents alone before the required <tool_response> confirms the operation succeeded.\n\
For concrete file, note, or search requests, emit the next <tool_call> immediately instead of describing a plan first.\n\
Example:\n\
User: Write exactly hello to tmp/example.txt and then read it back.\n\
Assistant:\n\
<tool_call>\n\
{\"name\":\"write_file\",\"arguments\":{\"path\":\"tmp/example.txt\",\"content\":\"hello\"}}\n\
</tool_call>\n\
After the write_file <tool_response> arrives:\n\
<tool_call>\n\
{\"name\":\"read_file\",\"arguments\":{\"path\":\"tmp/example.txt\"}}\n\
</tool_call>"
    );

    if input.tools.is_empty() {
        prompt.push_str("\nNo tools are available for this turn. Respond directly without emitting <tool_call> tags.");
    }

    if let Some(instructions) = trimmed_instructions {
        prompt.push('\n');
        prompt.push_str(instructions);
    }

    prompt
}

pub fn build_messages(
    system_prompt: &str,
    history: &[RuntimeMessage],
    tool_results: &[RuntimeToolResult],
) -> Vec<RuntimeMessage> {
    let mut messages =
        Vec::with_capacity(1 + history.len() + usize::from(!tool_results.is_empty()));
    messages.push(RuntimeMessage {
        role: RuntimeMessageRole::System,
        content: system_prompt.to_string(),
    });
    messages.extend_from_slice(history);

    if !tool_results.is_empty() {
        let content = tool_results
            .iter()
            .map(|result| format!("<tool_response>\n{}\n</tool_response>", result.result_json))
            .collect::<Vec<_>>()
            .join("\n");
        messages.push(RuntimeMessage {
            role: RuntimeMessageRole::Tool,
            content,
        });
    }

    messages
}

fn formatted_tools_json(tools: &[RuntimeToolDefinition]) -> String {
    let records = tools
        .iter()
        .map(|tool| {
            json!({
                "type": "function",
                "function": {
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": tool.parameters,
                }
            })
        })
        .collect::<Vec<_>>();

    serde_json::to_string(&records).unwrap_or_else(|_| "[]".to_string())
}
