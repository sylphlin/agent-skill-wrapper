---
name: skill-creator
description: Guide for creating effective skills. This skill should be used when users want to create a new skill (or update an existing skill) that extends Gemini's capabilities with specialized knowledge, workflows, or tool integrations.
license: Complete terms in LICENSE.txt
---
# Skill Creator
This skill provides a streamlined guide for understanding user intent and generating custom, high-quality `SKILL.md` files that users can immediately copy, download, and take away.
## About Skills
Skills are modular, self-contained packages that extend Gemini's capabilities by providing specialized knowledge, workflows, and rules. Think of a skill as an "onboarding guide" or "expert instructions" for a specific domain—it transforms a general-purpose Gemini model into a specialized agent equipped with procedural expertise.
### Anatomy of a Standalone `SKILL.md` File
A standard custom skill is stored as a single `SKILL.md` file. It consists of two required sections:
1. **YAML Frontmatter (Metadata)**: Enclosed in triple dashes (`---`) at the very top, containing the skill's identity and load triggers.
2. **Instruction Body (Markdown)**: The detailed behavior, steps, and rules for Gemini to follow.
```markdown
---
name: skill-name-with-hyphens
description: A concise, action-focused description explaining when Gemini should load this skill.
---
# Skill Title
Detailed instructional guidelines, workflows, and rules written in imperative form...
```
---
## The Streamlined Skill Creation Flow
The generation process is designed as a direct, conversational journey. Skip complex tooling and follow these three simple steps to produce and deliver the final `SKILL.md` file.
### Step 1: Understand Intent & Triggers
Engage with the user to discover what they want the skill to achieve. Ask targeted questions to understand the scope and usage patterns:
- **Goal**: What specific task or domain should this skill specialize in?
- **Triggers**: What would a user say that should activate this skill?
- **Context & Examples**: Can you provide 1 or 2 concrete examples of input and expected outputs?
*Tip: Keep the questions concise to keep the conversation engaging and avoid overwhelming the user.*
### Step 2: Plan the Structure
Translate the user's intent into a structured set of instructions. Ensure the design follows these core principles:
1. **Frontmatter Compliance**:
   - **`name`**: 1 to 64 characters, lowercase letters, numbers, and hyphens (`-`) only. Must not contain consecutive hyphens.
   - **`description`**: Under 1024 characters. Write in a highly descriptive, situational style so that Gemini can accurately decide when to trigger this skill.
2. **Imperative Writing Style**: Write instructions using the **imperative/infinitive form** (verb-first instructions, e.g., "Analyze the input", "Verify the structure") rather than the second person ("You should do...").
3. **Progressive Disclosure**: Keep the main instruction set concise and highly action-oriented. If the skill requires massive lookup data, schemas, or standard templates, advise the user to put those into a separate folder (e.g., `references/` or `assets/`) and link them, keeping the core `SKILL.md` file lean.
### Step 3: Generate & Deliver the SKILL.md
Produce the final, self-contained `SKILL.md` file code block. Output it clearly so the user can easily copy and take it away.
Along with the generated file, provide the user with simple options on how to utilize their new `SKILL.md` file:
- **Option 1: Project Customization**:
  Save the file in their project workspace under `.agent/skills/<skill-name>/SKILL.md`. Gemini will automatically discover and load the skill.
- **Option 2: Universal Global Use**:
  Save the file under their global Gemini configuration path: `~/.gemini/config/skills/<skill-name>/SKILL.md` to make the skill universally available across all directories on their machine.
- **Option 3: External Platforms (AI Studio / Vertex AI / API)**:
  Copy the markdown instruction body and paste it directly into the **System Instructions** (system prompt) box of Google AI Studio, Vertex AI, or supply it as the `system_instruction` in the Gemini API.