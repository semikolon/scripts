### 1. Refine Chunking Strategy

***Why:** A refined chunking strategy ensures that the AI model captures sufficient context from the code while maintaining granularity in the embeddings. Overlapping chunks prevent loss of context, especially when meaningful constructs might be split.*

- [x]  Implement the chunking size of 300-500 tokens.
    - [x]  Determine the optimal overlap size.
    - [x]  Update the chunking algorithm to include overlaps.
- [x]  Update the `create_embeddings.rb` script.
    - [x]  Integrate the new chunking logic.
    - [x]  Test with sample codebases for validation.

### 2. Metadata Capture

***Why:** Metadata provides crucial context for each code chunk, enabling accurate git patch generation and ensuring that the AI model can reference specific parts of the codebase.*

- [x]  Modify the chunking process.
    - [x]  Extract `filename` for each chunk.
    - [x]  Determine and store the relative `filepath`.
    - [x]  Capture an array of `line_numbers`.
- [x]  Validate metadata accuracy.
    - [x]  Cross-check with original files.
    - [x]  Ensure line numbers align with actual content.

### 3. Embedding Generation

***Why:** Unique semantic embeddings ensure that the AI model can retrieve distinct and meaningful information from the codebase, enhancing the efficiency of the retrieval-augmented generation process.*

- [ ]  Update the `generate_embeddings.rb` script.
    - [x]  Integrate logic to handle unique semantic chunks.
    - [ ]  Optimize the embedding generation process for efficiency.
- [ ]  Validate embeddings.
    - [x]  Ensure embeddings capture distinct semantic information.
    - [ ]  Test retrieval-augmented generation with sample queries.
    - Comment: We can only really get a sense of this once we've finished the whole array of scripts, uploaded embeddings, and are using them from CodeGPT in VS Code. That's when we'll stress test the RAG also. The RAG is built-in to CodeGPT.

### 4. Testing

***Why:** Thorough testing ensures that the chunking, metadata capture, and embedding generation processes work as intended, guaranteeing the reliability and accuracy of the system.*

- [ ]  Set up a testing environment.
    - [ ]  Create sample codebases for testing.
    - [ ]  Define expected outcomes for validation.
- [ ]  Conduct thorough testing.
    - [ ]  Validate chunking logic.
    - [ ]  Ensure metadata accuracy.
    - [ ]  Test embedding generation and retrieval.
- [ ]  Implement automatic testing using RSpec.
    - [ ]  Set up RSpec for the project.
    - [ ]  Write basic unit tests for core functionalities.
    - [ ]  Ensure tests run successfully and catch potential issues.
    - [ ]  Integrate RSpec tests into the development workflow for continuous testing.

### 5. Embeddings for Current Project

***Why:** While dependencies provide crucial context, the core logic and unique features of a project reside in its own code. Embeddings for the current project ensure that the AI model understands and can assist with the specific nuances and requirements of the project at hand.*

- [x]  Analyze the current project's codebase.
    - [x]  Identify and list potential sources of sensitive data.
    - [x]  Design a filtering mechanism to exclude sensitive data during embedding generation.
- [x]  Update the `generate_embeddings.rb` script.
    - [x]  Integrate logic to handle the current project's code.
    - [x]  Ensure sensitive data is excluded from the embeddings.
- [ ]  Validate the embeddings.
    - [ ]  Test retrieval-augmented generation with project-specific queries.
    - [ ]  Ensure no sensitive data is retrievable from the embeddings.

### 6. Plan for Git Patch Generation

***Why:** Git patch generation will allow developers to apply AI-suggested changes directly to their codebase, streamlining the development process and ensuring that AI-generated code integrates seamlessly.*

- [ ]  Design the git patch generation process.
    - [ ]  Determine the necessary inputs and outputs.
    - [ ]  Draft a flowchart or process diagram.
- [ ]  Implementation.
    - [ ]  Develop scripts or tools for git patch generation.
    - [ ]  Test with sample codebases and validate patches.