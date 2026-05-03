# Post-Merge Guards - agent-event-mlx-image-generation-pr23

- grep: `rg -n 'mlx-image-generation|image_generate\\.mlx|recordImageGenerationAgentEvent' Epistemos/Engine/MLXImageGenerationService.swift EpistemosTests`
- forbidden grep: prompt text, image path, result envelope body, localized error prose, FAL hints, provider credentials, and arbitrary error text are not persisted in AgentEvent JSON.
- log: `/tmp/epistemos-agent-event-mlx-image-generation-pr23-green-20260503.log` contains `** TEST SUCCEEDED **`
- test: `MLXImageGenerationServiceTests`
