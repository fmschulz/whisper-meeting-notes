Building agents with the Claude Agent SDK

Published Sep 29, 2025

The Claude Agent SDK is a collection of tools that helps developers build powerful agents on top of Claude Code. In this article, we walk through how to get started and share our best practices.

Last year, we shared lessons in building effective agents alongside our customers. Since then, we've released Claude Code, an agentic coding solution that we originally built to support developer productivity at Anthropic.

Over the past several months, Claude Code has become far more than a coding tool. At Anthropic, we’ve been using it for deep research, video creation, and note-taking, among countless other non-coding applications. In fact, it has begun to power almost all of our major agent loops.

In other words, the agent harness that powers Claude Code (the Claude Code SDK) can power many other types of agents, too. To reflect this broader vision, we're renaming the Claude Code SDK to the Claude Agent SDK.

In this post, we'll highlight why we built the Claude Agent SDK, how to build your own agents with it, and share the best practices that have emerged from our team’s own deployments.
Giving Claude a computer

The key design principle behind Claude Code is that Claude needs the same tools that programmers use every day. It needs to be able to find appropriate files in a codebase, write and edit files, lint the code, run it, debug, edit, and sometimes take these actions iteratively until the code succeeds.

We found that by giving Claude access to the user’s computer (via the terminal), it had what it needed to write code like programmers do.

But this has also made Claude in Claude Code effective at non-coding tasks. By giving it tools to run bash commands, edit files, create files and search files, Claude can read CSV files, search the web, build visualizations, interpret metrics, and do all sorts of other digital work – in short, create general-purpose agents with a computer. The key design principle behind the Claude Agent SDK is to give your agents a computer, allowing them to work like humans do.
Creating new types of agents

We believe giving Claude a computer unlocks the ability to build agents that are more effective than before. For example, with our SDK, developers can build:

    Finance agents: Build agents that can understand your portfolio and goals, as well as help you evaluate investments by accessing external APIs, storing data and running code to make calculations.
    Personal assistant agents. Build agents that can help you book travel and manage your calendar, as well as schedule appointments, put together briefs, and more by connecting to your internal data sources and tracking context across applications.
    Customer support agents: Build agents that can handle high ambiguity user requests, like customer service tickets, by collecting and reviewing user data, connecting to external APIs, messaging users back and escalating to humans when needed.
    Deep research agents: Build agents that can conduct comprehensive research across large document collections by searching through file systems, analyzing and synthesizing information from multiple sources, cross-referencing data across files, and generating detailed reports.

And much more. At its core, the SDK gives you the primitives to build agents for whatever workflow you're trying to automate.
Building your agent loop

In Claude Code, Claude often operates in a specific feedback loop: gather context -> take action -> verify work -> repeat.
Agent feedback loop
Agents often operate in a specific feedback loop: gather context -> take action -> verify work -> repeat.

This offers a useful way to think about other agents, and the capabilities they should be given. To illustrate this, we’ll walk through the example of how we might build an email agent in the Claude Agent SDK.
Gather context

When developing an agent, you want to give it more than just a prompt: it needs to be able to fetch and update its own context. Here’s how features in the SDK can help.
Agentic search and the file system

The file system represents information that could be pulled into the model's context.

When Claude encounters large files, like logs or user-uploaded files, it will decide which way to load these into its context by using bash scripts like grep and tail. In essence, the folder and file structure of an agent becomes a form of context engineering.

Our email agent might store previous conversations in a folder called ‘Conversations’. This would allow it to search previous these for its context when asked about them.
Semantic search

Semantic search is usually faster than agentic search, but less accurate, more difficult to maintain, and less transparent. It involves ‘chunking’ the relevant context, embedding these chunks as vectors, and then searching for concepts by querying those vectors. Given its limitations, we suggest starting with agentic search, and only adding semantic search if you need faster results or more variations.
Subagents

Claude Agent SDK supports subagents by default. Subagents are useful for two main reasons. First, they enable parallelization: you can spin up multiple subagents to work on different tasks simultaneously. Second, they help manage context: subagents use their own isolated context windows, and only send relevant information back to the orchestrator, rather than their full context. This makes them ideal for tasks that require sifting through large amounts of information where most of it won't be useful.

When designing our email agent, we might give it a 'search subagent' capability. The email agent could then spin off multiple search subagents in parallel—each running different queries against your email history—and have them return only the relevant excerpts rather than full email threads.
Compaction

When agents are running for long periods of time, context maintenance becomes critical. The Claude Agent SDK’s compact feature automatically summarizes previous messages when the context limit approaches, so your agent won’t run out of context. This is built on Claude Code’s compact slash command.
Take action

Once you’ve gathered context, you’ll want to give your agent flexible ways of taking action.
Tools

Tools are the primary building blocks of execution for your agent. Tools are prominent in Claude's context window, making them the primary actions Claude will consider when deciding how to complete a task. This means you should be conscious about how you design your tools to maximize context efficiency. You can see more best practices in our blog post, Writing effective tools for agents – with agents .

As such, your tools should be primary actions you want your agent to take. Learn how to make custom tools in the Claude Agent SDK.

For our email agent, we might define tools like “fetchInbox” or “searchEmails” as the agent’s primary, most frequent actions.
Bash & scripts

Bash is useful as a general-purpose tool to allow the agent to do flexible work using a computer.

In our email agent, the user might have important information stored in their attachments. Claude could write code to download the PDF, convert it to text, and search across it to find useful information by calling, as depicted below:
Code generation

The Claude Agent SDK excels at code generation—and for good reason. Code is precise, composable, and infinitely reusable, making it an ideal output for agents that need to perform complex operations reliably.

When building agents, consider: which tasks would benefit from being expressed as code? Often, the answer unlocks significant capabilities.

For example, our recent launch of file creation in Claude.AI relies entirely on code generation. Claude writes Python scripts to create Excel spreadsheets, PowerPoint presentations, and Word documents, ensuring consistent formatting and complex functionality that would be difficult to achieve any other way.

In our email agent, we might want to allow users to create rules for inbound emails. To achieve this, we could write code to run on that event:
MCPs

The Model Context Protocol (MCP) provides standardized integrations to external services, handling authentication and API calls automatically. This means you can connect your agent to tools like Slack, GitHub, Google Drive, or Asana without writing custom integration code or managing OAuth flows yourself.

For our email agent, we might want to search Slack messages to understand team context, or check Asana tasks to see if someone has already been assigned to handle a customer request. With MCP servers, these integrations work out of the box—your agent can simply call tools like search_slack_messages or get_asana_tasks and the MCP handles the rest.

The growing MCP ecosystem means you can quickly add new capabilities to your agents as pre-built integrations become available, letting you focus on agent behavior.
Verify your work

The Claude Code SDK finishes the agentic loop by evaluating its work. Agents that can check and improve their own output are fundamentally more reliable—they catch mistakes before they compound, self-correct when they drift, and get better as they iterate.

The key is giving Claude concrete ways to evaluate its work. Here are three approaches we've found effective:
Defining rules

The best form of feedback is providing clearly defined rules for an output, then explaining which rules failed and why.

Code linting is an excellent form of rules-based feedback. The more in-depth in feedback the better. For instance, it is usually better to generate TypeScript and lint it than it is to generate pure JavaScript because it provides you with multiple additional layers of feedback.

When generating an email, you may want Claude to check that the email address is valid (if not, throw an error) and that the user has sent an email to them before (if so, throw a warning).
Visual feedback

When using an agent to complete visual tasks, like UI generation or testing, visual feedback (in the form of screenshots or renders) can be helpful. For example, if sending an email with HTML formatting, you could screenshot the generated email and provide it back to the model for visual verification and iterative refinement. The model would then check whether the visual output matches what was requested.

For instance:

    Layout - Are elements positioned correctly? Is spacing appropriate?
    Styling - Do colors, fonts, and formatting appear as intended?
    Content hierarchy - Is information presented in the right order with proper emphasis?
    Responsiveness - Does it look broken or cramped? (though a single screenshot has limited viewport info)

Using an MCP server like Playwright, you can automate this visual feedback loop—taking screenshots of rendered HTML, capturing different viewport sizes, and even testing interactive elements—all within your agent's workflow.
Claude provides visual feedback on the body of an email generated by an agent.
Visual feedback from a large-language model (LLM) can provide helpful guidance to your agent.
LLM as a judge

You can also have another language model “judge" the output of your agent based on fuzzy rules. This is generally not a very robust method, and can have heavy latency tradeoffs, but for applications where any boost in performance is worth the cost, it can be helpful.

Our email agent might have a separate subagent judge the tone of its drafts, to see if they fit well with the user’s previous messages.
Testing and improving your agent

After you’ve gone through the agent loop a few times, we recommend testing your agent, and ensuring that it’s well-equipped for its tasks. The best way to improve an agent is to look carefully at its output, especially the cases where it fails, and to put yourself in its shoes: does it have the right tools for the job?

Here are some other questions to ask as you’re evaluating whether or not your agent is well-equipped to do its job:

    If your agent misunderstands the task, it might be missing key information. Can you alter the structure of your search APIs to make it easier to find what it needs to know?
    If your agent fails at a task repeatedly, can you add a formal rule in your tool calls to identify and fix the failure?
    If your agent can’t fix its errors, can you give it more useful or creative tools to approach the problem differently?
    If your agent’s performance varies as you add features, build a representative test set for programmatic evaluations (or evals) based on customer usage.

Getting started

The Claude Agent SDK makes it easier to build autonomous agents by giving Claude access to a computer where it can write files, run commands, and iterate on its work.

With the agent loop in mind (gathering context, taking action, and your verifying work), you can build reliable agents that are easy to deploy and iterate on.

You can get started with the Claude Agent SDK today. For developers who are already building on the SDK, we recommend migrating to the latest version by following this guide.
Acknowledgements

Written by Thariq Shihipar with notes and editing from Molly Vorwerck, Suzanne Wang, Alex Isken, Cat Wu, Keir Bradwell, Alexander Bricken & Ashwin Bhat.

Code execution with MCP: Building more efficient agents

Published Nov 04, 2025

Direct tool calls consume context for each definition and result. Agents scale better by writing code to call tools instead. Here's how it works with MCP.

The Model Context Protocol (MCP) is an open standard for connecting AI agents to external systems. Connecting agents to tools and data traditionally requires a custom integration for each pairing, creating fragmentation and duplicated effort that makes it difficult to scale truly connected systems. MCP provides a universal protocol—developers implement MCP once in their agent and it unlocks an entire ecosystem of integrations.

Since launching MCP in November 2024, adoption has been rapid: the community has built thousands of MCP servers, SDKs are available for all major programming languages, and the industry has adopted MCP as the de-facto standard for connecting agents to tools and data.

Today developers routinely build agents with access to hundreds or thousands of tools across dozens of MCP servers. However, as the number of connected tools grows, loading all tool definitions upfront and passing intermediate results through the context window slows down agents and increases costs.

In this blog we'll explore how code execution can enable agents to interact with MCP servers more efficiently, handling more tools while using fewer tokens.
Excessive token consumption from tools makes agents less efficient

As MCP usage scales, there are two common patterns that can increase agent cost and latency:

    Tool definitions overload the context window;
    Intermediate tool results consume additional tokens.

1. Tool definitions overload the context window

Most MCP clients load all tool definitions upfront directly into context, exposing them to the model using a direct tool-calling syntax. These tool definitions might look like:

gdrive.getDocument
     Description: Retrieves a document from Google Drive
     Parameters:
                documentId (required, string): The ID of the document to retrieve
                fields (optional, string): Specific fields to return
     Returns: Document object with title, body content, metadata, permissions, etc.

salesforce.updateRecord
    Description: Updates a record in Salesforce
    Parameters:
               objectType (required, string): Type of Salesforce object (Lead, Contact,      Account, etc.)
               recordId (required, string): The ID of the record to update
               data (required, object): Fields to update with their new values
     Returns: Updated record object with confirmation

Tool descriptions occupy more context window space, increasing response time and costs. In cases where agents are connected to thousands of tools, they’ll need to process hundreds of thousands of tokens before reading a request.
2. Intermediate tool results consume additional tokens

Most MCP clients allow models to directly call MCP tools. For example, you might ask your agent: "Download my meeting transcript from Google Drive and attach it to the Salesforce lead."

The model will make calls like:

TOOL CALL: gdrive.getDocument(documentId: "abc123")
        → returns "Discussed Q4 goals...\n[full transcript text]"
           (loaded into model context)

TOOL CALL: salesforce.updateRecord(
			objectType: "SalesMeeting",
			recordId: "00Q5f000001abcXYZ",
  			data: { "Notes": "Discussed Q4 goals...\n[full transcript text written out]" }
		)
		(model needs to write entire transcript into context again)

Every intermediate result must pass through the model. In this example, the full call transcript flows through twice. For a 2-hour sales meeting, that could mean processing an additional 50,000 tokens. Even larger documents may exceed context window limits, breaking the workflow.

With large documents or complex data structures, models may be more likely to make mistakes when copying data between tool calls.
Image of how the MCP client works with the MCP server and LLM.
The MCP client loads tool definitions into the model's context window and orchestrates a message loop where each tool call and result passes through the model between operations.
Code execution with MCP improves context efficiency

With code execution environments becoming more common for agents, a solution is to present MCP servers as code APIs rather than direct tool calls. The agent can then write code to interact with MCP servers. This approach addresses both challenges: agents can load only the tools they need and process data in the execution environment before passing results back to the model.

There are a number of ways to do this. One approach is to generate a file tree of all available tools from connected MCP servers. Here's an implementation using TypeScript:

servers
├── google-drive
│   ├── getDocument.ts
│   ├── ... (other tools)
│   └── index.ts
├── salesforce
│   ├── updateRecord.ts
│   ├── ... (other tools)
│   └── index.ts
└── ... (other servers)

Then each tool corresponds to a file, something like:

// ./servers/google-drive/getDocument.ts
import { callMCPTool } from "../../../client.js";

interface GetDocumentInput {
  documentId: string;
}

interface GetDocumentResponse {
  content: string;
}

/* Read a document from Google Drive */
export async function getDocument(input: GetDocumentInput): Promise<GetDocumentResponse> {
  return callMCPTool<GetDocumentResponse>('google_drive__get_document', input);
}

Our Google Drive to Salesforce example above becomes the code:

// Read transcript from Google Docs and add to Salesforce prospect
import * as gdrive from './servers/google-drive';
import * as salesforce from './servers/salesforce';

const transcript = (await gdrive.getDocument({ documentId: 'abc123' })).content;
await salesforce.updateRecord({
  objectType: 'SalesMeeting',
  recordId: '00Q5f000001abcXYZ',
  data: { Notes: transcript }
});

The agent discovers tools by exploring the filesystem: listing the ./servers/ directory to find available servers (like google-drive and salesforce), then reading the specific tool files it needs (like getDocument.ts and updateRecord.ts) to understand each tool's interface. This lets the agent load only the definitions it needs for the current task. This reduces the token usage from 150,000 tokens to 2,000 tokens—a time and cost saving of 98.7%.

Cloudflare published similar findings, referring to code execution with MCP as “Code Mode." The core insight is the same: LLMs are adept at writing code and developers should take advantage of this strength to build agents that interact with MCP servers more efficiently.
Benefits of code execution with MCP

Code execution with MCP enables agents to use context more efficiently by loading tools on demand, filtering data before it reaches the model, and executing complex logic in a single step. There are also security and state management benefits to using this approach.
Progressive disclosure

Models are great at navigating filesystems. Presenting tools as code on a filesystem allows models to read tool definitions on-demand, rather than reading them all up-front.

Alternatively, a search_tools tool can be added to the server to find relevant definitions. For example, when working with the hypothetical Salesforce server used above, the agent searches for "salesforce" and loads only those tools that it needs for the current task. Including a detail level parameter in the search_tools tool that allows the agent to select the level of detail required (such as name only, name and description, or the full definition with schemas) also helps the agent conserve context and find tools efficiently.
Context efficient tool results

When working with large datasets, agents can filter and transform results in code before returning them. Consider fetching a 10,000-row spreadsheet:

// Without code execution - all rows flow through context
TOOL CALL: gdrive.getSheet(sheetId: 'abc123')
        → returns 10,000 rows in context to filter manually

// With code execution - filter in the execution environment
const allRows = await gdrive.getSheet({ sheetId: 'abc123' });
const pendingOrders = allRows.filter(row => 
  row["Status"] === 'pending'
);
console.log(`Found ${pendingOrders.length} pending orders`);
console.log(pendingOrders.slice(0, 5)); // Only log first 5 for review

The agent sees five rows instead of 10,000. Similar patterns work for aggregations, joins across multiple data sources, or extracting specific fields—all without bloating the context window.
More powerful and context-efficient control flow

Loops, conditionals, and error handling can be done with familiar code patterns rather than chaining individual tool calls. For example, if you need a deployment notification in Slack, the agent can write:

let found = false;
while (!found) {
  const messages = await slack.getChannelHistory({ channel: 'C123456' });
  found = messages.some(m => m.text.includes('deployment complete'));
  if (!found) await new Promise(r => setTimeout(r, 5000));
}
console.log('Deployment notification received');

This approach is more efficient than alternating between MCP tool calls and sleep commands through the agent loop.

Additionally, being able to write out a conditional tree that gets executed also saves on “time to first token” latency: rather than having to wait for a model to evaluate an if-statement, the agent can let the code execution environment do this.
Privacy-preserving operations

When agents use code execution with MCP, intermediate results stay in the execution environment by default. This way, the agent only sees what you explicitly log or return, meaning data you don’t wish to share with the model can flow through your workflow without ever entering the model's context.

For even more sensitive workloads, the agent harness can tokenize sensitive data automatically. For example, imagine you need to import customer contact details from a spreadsheet into Salesforce. The agent writes:

const sheet = await gdrive.getSheet({ sheetId: 'abc123' });
for (const row of sheet.rows) {
  await salesforce.updateRecord({
    objectType: 'Lead',
    recordId: row.salesforceId,
    data: { 
      Email: row.email,
      Phone: row.phone,
      Name: row.name
    }
  });
}
console.log(`Updated ${sheet.rows.length} leads`);

The MCP client intercepts the data and tokenizes PII before it reaches the model:

// What the agent would see, if it logged the sheet.rows:
[
  { salesforceId: '00Q...', email: '[EMAIL_1]', phone: '[PHONE_1]', name: '[NAME_1]' },
  { salesforceId: '00Q...', email: '[EMAIL_2]', phone: '[PHONE_2]', name: '[NAME_2]' },
  ...
]

Then, when the data is shared in another MCP tool call, it is untokenized via a lookup in the MCP client. The real email addresses, phone numbers, and names flow from Google Sheets to Salesforce, but never through the model. This prevents the agent from accidentally logging or processing sensitive data. You can also use this to define deterministic security rules, choosing where data can flow to and from.
State persistence and skills

Code execution with filesystem access allows agents to maintain state across operations. Agents can write intermediate results to files, enabling them to resume work and track progress:

const leads = await salesforce.query({ 
  query: 'SELECT Id, Email FROM Lead LIMIT 1000' 
});
const csvData = leads.map(l => `${l.Id},${l.Email}`).join('\n');
await fs.writeFile('./workspace/leads.csv', csvData);

// Later execution picks up where it left off
const saved = await fs.readFile('./workspace/leads.csv', 'utf-8');

Agents can also persist their own code as reusable functions. Once an agent develops working code for a task, it can save that implementation for future use:

// In ./skills/save-sheet-as-csv.ts
import * as gdrive from './servers/google-drive';
export async function saveSheetAsCsv(sheetId: string) {
  const data = await gdrive.getSheet({ sheetId });
  const csv = data.map(row => row.join(',')).join('\n');
  await fs.writeFile(`./workspace/sheet-${sheetId}.csv`, csv);
  return `./workspace/sheet-${sheetId}.csv`;
}

// Later, in any agent execution:
import { saveSheetAsCsv } from './skills/save-sheet-as-csv';
const csvPath = await saveSheetAsCsv('abc123');

This ties in closely to the concept of Skills, folders of reusable instructions, scripts, and resources for models to improve performance on specialized tasks. Adding a SKILL.md file to these saved functions creates a structured skill that models can reference and use. Over time, this allows your agent to build a toolbox of higher-level capabilities, evolving the scaffolding that it needs to work most effectively.

Note that code execution introduces its own complexity. Running agent-generated code requires a secure execution environment with appropriate sandboxing, resource limits, and monitoring. These infrastructure requirements add operational overhead and security considerations that direct tool calls avoid. The benefits of code execution—reduced token costs, lower latency, and improved tool composition—should be weighed against these implementation costs.
Summary

MCP provides a foundational protocol for agents to connect to many tools and systems. However, once too many servers are connected, tool definitions and results can consume excessive tokens, reducing agent efficiency.

Although many of the problems here feel novel—context management, tool composition, state persistence—they have known solutions from software engineering. Code execution applies these established patterns to agents, letting them use familiar programming constructs to interact with MCP servers more efficiently. If you implement this approach, we encourage you to share your findings with the MCP community.
Acknowledgments

This article was written by Adam Jones and Conor Kelly. Thanks to Jeremy Fox, Jerome Swannack, Stuart Ritchie, Molly Vorwerck, Matt Samuels, and Maggie Vo for feedback on drafts of this post.
