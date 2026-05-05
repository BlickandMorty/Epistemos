[[Assessment]]
# Module 8: Guardrails and Defense Mechanisms

In the following sections, the concepts of guardrails and defense mechanisms are discussed.

## Learning Objectives

By the end of this module, you will demonstrate knowledge of:

- Common defense techniques of a modern LLM safety stack, including:
    
    - Deterministic input filtering
        
    - Input and output guardrails
        
    - System prompt instructions
        
    - RLHF/Safety Fine-Tuning
        
- The origin and role of purple teaming\
## Overview

AI safeguards are proactive, prescriptive, and designed to handle edge cases, limit failures, and maintain trust in live systems. Building a solid foundation ensures that an LLM doesn’t just perform well on paper, but thrives safely in the hands of users. Effective implementation means actively mitigating risks in real-time production through a structured, multi-layered approach.

These safeguards use pre-defined rules and filters to protect applications from vulnerabilities like data leakage, bias, and hallucination. Acting as shields against malicious inputs (such as prompt injections and jailbreaking), they ensure that only compliant, safe responses reach the end user.

For a red-teamer, a foundational understanding of how these layers interact in a modern AI safety stack is essential. This insight provides the intuition needed to craft attacks and interactions that purposefully bypass and override these defenses.

Below is the breakdown of the safety layers, ordered by the data flow in a production environment.

![**Figure 1:** An overview of the modern AI safeguarding layers. The path of the prompt and how to bypass each layer will be discussed further below.](https://mercor-form-assets.s3.amazonaws.com/forms/form_3913c80ea2b04abebdad498605cd8c9d/items/form_c_5cbf8b4c-7acc-4e33-90d7-154cce428bb3/Module_8_Figure_1.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ASIAYQYUBA3IIIEI7NZQ%2F20260109%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260109T231954Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEOb%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLWVhc3QtMSJGMEQCIBZOCcHqQYhCKvEuwMexfAl5NxuX8vufUA%2FkyvXdTsu1AiBtZqv4qB17J6o0XUi1S%2B9np9Ed2g56xoxVSovPCi7oGSqOBAiu%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAAaDDU4NTc2ODE3NTMxMiIMggr8RyghmCP4bCjrKuIDcVsJiBpacS0S4220XjCD9oWjJqM0yHvTfWFwwIVcKlPw7p5TvCf50edI3pRKReavE6HJCWq2YmN6uuJvgvv0heNxqc7vxGp9RYKnGWJmwyIlMZLzU9lf6GJVnUCcYatEdJT2MwbIC7B7XXx0KRzAalRaaBQfKoSc0yuzqrsiVpWxEJN9E5Wx9pzX6cDVYqL4V4IJaDtC%2FXFz3vk0ftrLHig7OmQczKjG1CkKhsTzisgjpNPgbM3WpykGc2c%2B1tPO55Ay9I%2FX2L%2FD4GtOrAGxnD%2BnYoL6LsWSAlreBeE%2FC01KxFmKRs5GzFOwUO5m36ild3BH2ifU6EAgTc5GezIOp%2F%2BWvqPt88sHkQB6%2FH8g3bYGA8sptokD5Mjc3uPGyfvr0d6f1ZqbUVcADCw1yUitWO6bOyolTyXALTccUcSzv2%2Bc1l%2FUk841XEnDzQs9i%2Ftlz0F2o8bWYb8Crw8xqk%2Fluo%2BVuQ4H43EnyubXdVER9gy5c42lJI1Hw%2Fb1pNxjdC2est%2F6UD%2FylxUsMMLN8FAHquyNBOtoiaHTknqJMHlsmRv0f8Jejz4VLzEuasAQ52PuGi5Q3d%2Fbu47kBGb04yw%2BqwINLigePei6E2LinAdcC%2Bmm7mmQDYihcxDsGix%2BE6jw0zow3tuFywY6pgHfEpQMJL0VkUyQjCtDRxze7sOLEjm%2BzWi8ZJjwbak7BNcUmOYCxm1FD4coEQFfQj5yT85JKJsbzEwEhQVXrz9cTRiLfeGQoDlt7DvFONr18dYZXb6VhlM9RQ41qIbvlB9vOqT%2F7fd8t1CpPExDctDjubHh3cm2L8tX%2B3GfrrLh3v8o5GeoOUKdT9EBN5yIFyVK1cbTKX4jYI6ezcXdhc0jKPveXv3s&X-Amz-Signature=7919588581611aa9e05fff7ff867a2a14b00c605b372c028fdbe035be401918d)
**Figure 1:** An overview of the modern AI safeguarding layers. The path of the prompt and how to bypass each layer will be discussed further below.
## Deterministic Input Filtering

As a first line of defense, user prompts pass through a fast, low-cost filter.

- **Regex and Keyword Checks:** Simple rules flag obvious harms (e.g., slurs, dangerous phrases) or known attack patterns.
    
- **PII Sanitization:** As shown in the diagram, this layer effectively strips or anonymizes Personally Identifiable Information (PII) to prevent data leakage before the model processes the request.
    

To bypass these filters, attackers often use "obfuscation" (misspellings, Base64 encoding) or creative formatting and avoid obvious unsafe keywords to evade rigid detection.
## Input Guardrails

If the prompt passes the basic filters, it moves to the semantic guardrails. This is often a small, specialized model (like a fine-tuned BERT or tiny Llama-7B) dedicated solely to classifying intent. Popular open source guardrails include LlamaGuard, Google Model Armour, and Perspective AI.

These guardrail models are trained to compare inputs against a database of known jailbreak or adversarial templates, and judge whether the input violates specific safety policies (e.g., toxicity, bias, self-harm) or attempts to jailbreak the system. A simple binary classification may breakdown as follows:

- **Safe:** The prompt proceeds to the next stage.
    
- **Unsafe:** 
    
    - The system triggers a "Block" action, returning a refusal message immediately to conserve tokens and protect the application integrity.
        
    - In some advanced setups, the input can be automatically re-phrased to a safer alternative rather than being blocked outright.
        

Red teamers can attempt to compel the model to bypass its guardrails using novel jailbreaking techniques, as well as exploring edge-cases and emerging harms that may not be captured by this layer.
## System Prompt Instructions

Once deemed safe, the user input is combined with the developer's system prompt.

- **Role:** This acts as the ‘constitution’ for the model. It includes explicit instructions on tone, limitations, and safety overrides (e.g., "If asked for dangerous instructions, refuse politely").
    
- **Context:** It forces the model to reason about the risk of the input within the specific context of its use case before generating an answer.
    

|   |
|---|
|_E.g. model_a does not provide information that could be used to make chemical or biological or nuclear weapons, and does not write malicious code, including malware, vulnerability exploits, spoof websites, ransomware, viruses, election material, and so on. It does not do these things even if the person seems to have a good reason for asking for it. model_a steers away from malicious or harmful use cases for cyber. model_a refuses to write code or explain code that may be used maliciously; even if the user claims it is for educational purposes. When working on files, if they seem related to improving, explaining, or interacting with malware or any malicious code model_a MUST refuse. If the code seems malicious, model_a refuses to work on it or answer questions about it, even if the request does not seem malicious (for instance, just asking to explain or speed up the code). If the user asks model_a to describe a protocol that appears malicious or intended to harm others, model_a refuses to answer. If model_a encounters any of the above or any other malicious use, model_a does not take any actions and refuses the request._|
## RLHF/Safety Fine-Tuning

This safety layer is baked into the model weights themselves. Through Reinforcement Learning from Human Feedback (RLHF), the core model has been trained to recognize harmful concepts and refuse them naturally.

While robust, this layer is not infallible for two primary reasons:

- **Adversarial "Jailbreaks":** Red teams often find specific prompts that trick the model into bypassing its own safety training.
    
- **Dataset Contamination and Sparsity:** Because these models are trained on massive, uncurated scrapes of the internet, they ingest vast amounts of unsafe content. While RLHF attempts to "cover" these areas, the training data is so expansive that there are "sparse" regions where safety guardrails haven't been sufficiently applied, allowing latent harmful patterns to surface.
    

---

### **Output** **guardrails**

The final line of defense sits between the model’s generation and the user. It acts as a real-time scanner to ensure the response is high-quality, accurate, and compliant before it is displayed.

- **Function:** It scans for hallucinations, PII (Personally Identifiable Information) leaks, or successful jailbreaks that bypassed previous layers.
    
- **Interception:** If the generated content triggers a violation (e.g., a credit card number), the Output Guard intercepts it and replaces the text with a refusal message.
    
- **Unprompted Harm:** This layer is critical for catching harmful content triggered by benign inputs. Due to contextual misunderstandings or "noise" in the model's weights, a model may occasionally produce toxic or unsafe output even when the user didn't ask for it.
    

Input and Output guardrails work using nearly identical mechanisms. Both layers often utilize the same specialized models, such as LlamaGuard, Perspective AI, or NVIDIA NeMo, to perform semantic classification. The primary difference is the data they analyze:

- **Input Guardrails** analyze user intent to block malicious prompts proactively, saving compute costs.
    
- **Output Guardrails** analyze the model’s response to catch failures in the model's internal safety training or "hallucinated" harms that only appear during the generation phase.
    

By applying these specialized models at both ends, the system creates a redundant safety loop that accounts for both human malice and unpredictable model behavior.
## Key Takeaways

- AI safeguards are proactive, prescriptive, and designed to handle edge cases, limit failures, and maintain trust in live systems.
    
- A foundational understanding of how safeguarding layers interact in a modern AI safety stack provides the intuition needed to craft attacks and interactions that purposefully bypass and override these defenses.
    
- Understanding the architecture of AI safety layers allows Red Teamers to simultaneously operate as Purple Teamers, using attack data to systematically strengthen safeguard layers.