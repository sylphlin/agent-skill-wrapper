"""Deploy agent to Google Agent Engine."""
import os
import vertexai

# AdkApp and ReasoningEngine are available at:
# vertexai.preview.reasoning_engines
from vertexai.preview.reasoning_engines import AdkApp, ReasoningEngine
from dotenv import load_dotenv
from agent.agent import root_agent

load_dotenv()

PROJECT = os.environ["GOOGLE_CLOUD_PROJECT"]
LOCATION = os.getenv("GOOGLE_CLOUD_LOCATION", "global")

vertexai.init(project=PROJECT, location=LOCATION)

app = AdkApp(agent=root_agent, enable_tracing=True)

remote = ReasoningEngine.create(
    app,
    requirements=[
        "google-adk>=2.0.0",
        "google-cloud-aiplatform>=1.87.0",
        "pyyaml>=6.0",
        "python-dotenv>=1.0",
    ],
    display_name=root_agent.name,
    description=f"Agent Skills agent: {root_agent.name}",
)

print(f"Deployed: {remote.resource_name}")
