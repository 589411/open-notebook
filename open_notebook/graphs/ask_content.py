import os

from langchain_core.runnables import (
    RunnableConfig,
)
from langchain_openai import ChatOpenAI
from langgraph.graph import END, START, StateGraph
from loguru import logger
from typing_extensions import TypedDict

from open_notebook.domain import Note, Notebook, Source
from open_notebook.prompter import Prompter


class AskState(TypedDict):
    doc_id: str
    doc_content: str
    question: str
    answer: str
    notebook: Notebook


def call_model_with_messages(state: AskState, config: RunnableConfig) -> dict:
    model = ChatOpenAI(
        model=os.environ.get("RETRIEVAL_MODEL", os.environ["DEFAULT_MODEL"]),
        temperature=0,
    )
    system_prompt = Prompter(prompt_template="ask_content").render(data=state)
    logger.debug(f"System prompt: {system_prompt}")
    ai_message = model.invoke(system_prompt)
    return {"answer": ai_message}


# todo: there is probably a better way to do this and avoid repetition
def get_content(state: AskState) -> dict:
    doc_id = state["doc_id"]
    if "note:" in doc_id:
        doc: Note = Note.get(id=doc_id)
    elif "source:" in doc_id:
        doc: Source = Source.get(id=doc_id)
    doc_content = doc.get_context("long") if doc else None
    return {"doc_content": doc_content}


agent_state = StateGraph(AskState)
agent_state.add_node("get_content", get_content)
agent_state.add_node("agent", call_model_with_messages)
agent_state.add_edge(START, "get_content")
agent_state.add_edge("get_content", "agent")
agent_state.add_edge("agent", END)

graph = agent_state.compile()
