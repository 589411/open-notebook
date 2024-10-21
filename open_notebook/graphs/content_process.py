import re

import fitz  # type: ignore
import magic
import requests  # type: ignore
from langgraph.graph import END, START, StateGraph
from typing_extensions import TypedDict
from youtube_transcript_api import YouTubeTranscriptApi  # type: ignore
from youtube_transcript_api.formatters import TextFormatter  # type: ignore


class SourceState(TypedDict):
    content: str
    file_path: str
    url: str
    source_type: str
    identified_type: str
    identified_provider: str


def source_identification(state: SourceState):
    """
    Identify the content source based on parameters
    """
    if state.get("content"):
        doc_type = "text"
    elif state.get("file_path"):
        doc_type = "file"
    elif state.get("url"):
        doc_type = "url"
    else:
        raise ValueError("No source provided.")

    return {"source_type": doc_type}


def url_provider(state: SourceState):
    """
    Identify the provider
    """
    return_dict = {}
    url = state.get("url")
    if url:
        if "youtube.com" in url or "youtu.be" in url:
            return_dict["identified_type"] = (
                "youtube"  # playlists, channels in the future
            )
        else:
            return_dict["identified_type"] = "article"
            # article providers in the future
    return return_dict


def file_type(state: SourceState):
    """
    Identify the file using python-magic
    """
    return_dict = {}
    file_path = state.get("file_path")
    if file_path is not None:
        return_dict["identified_type"] = magic.from_file(file_path, mime=True)
    return return_dict


def _extract_text_from_pdf(pdf_path):
    doc = fitz.open(pdf_path)
    text = ""
    for page in doc:
        text += page.get_text()
    doc.close()
    return text


def extract_pdf(state: SourceState):
    """
    Parse the text file and print its content.
    """
    return_dict = {}
    if (
        state.get("file_path") is not None
        and state.get("identified_type") == "application/pdf"
    ):
        file_path = state.get("file_path")
        try:
            text = _extract_text_from_pdf(file_path)
            return_dict["content"] = text
        except FileNotFoundError:
            raise FileNotFoundError(f"File not found at {file_path}")
        except Exception as e:
            raise Exception(f"An error occurred: {e}")

    return return_dict


def extract_url(state: SourceState):
    """
    Get the content of a URL
    """
    response = requests.get(f"https://r.jina.ai/{state.get('url')}")
    return {"content": response.text}


def extract_txt(state: SourceState):
    """
    Parse the text file and print its content.
    """
    return_dict = {}
    if (
        state.get("file_path") is not None
        and state.get("identified_type") == "text/plain"
    ):
        file_path = state.get("file_path")
        if file_path is not None:
            try:
                with open(file_path, "r", encoding="utf-8") as file:
                    content = file.read()
                    return_dict["content"] = content
            except FileNotFoundError:
                raise FileNotFoundError(f"File not found at {file_path}")
            except Exception as e:
                raise Exception(f"An error occurred: {e}")

    return return_dict


def _extract_youtube_id(url):
    """
    Extract the YouTube video ID from a given URL using regular expressions.

    Args:
    url (str): The YouTube URL from which to extract the video ID.

    Returns:
    str: The extracted YouTube video ID or None if no valid ID is found.
    """
    # Define a regular expression pattern to capture the YouTube video ID
    youtube_regex = (
        r"(?:https?://)?"  # Optional scheme
        r"(?:www\.)?"  # Optional www.
        r"(?:"
        r"youtu\.be/"  # Shortened URL
        r"|youtube\.com"  # Main URL
        r"(?:"  # Group start
        r"/embed/"  # Embed URL
        r"|/v/"  # Older video URL
        r"|/watch\?v="  # Standard watch URL
        r"|/watch\?.+&v="  # Other watch URL
        r")"  # Group end
        r")"  # End main group
        r"([\w-]{11})"  # 11 characters (YouTube video ID)
    )

    # Search the URL for the pattern
    match = re.search(youtube_regex, url)

    # Return the video ID if a match is found
    return match.group(1) if match else None


def extract_youtube_transcript(state: SourceState):
    """
    Parse the text file and print its content.
    """

    transcript = YouTubeTranscriptApi.get_transcript(
        _extract_youtube_id(state.get("url")), languages=["pt", "en"]
    )
    formatter = TextFormatter()
    return {"content": formatter.format_transcript(transcript)}


def should_continue(data: SourceState):
    if data.get("source_type") == "url":
        return "parse_url"
    else:
        return "end"


workflow = StateGraph(SourceState)
workflow.add_node("source", source_identification)
workflow.add_node("url_provider", url_provider)
workflow.add_node("file_type", file_type)
workflow.add_node("extract_txt", extract_txt)
workflow.add_node("extract_pdf", extract_pdf)
workflow.add_node("extract_url", extract_url)
workflow.add_node("extract_youtube_transcript", extract_youtube_transcript)

workflow.add_edge(START, "source")
workflow.add_conditional_edges(
    "source",
    lambda x: x.get("source_type"),
    {
        "url": "url_provider",
        "file": "file_type",
        "text": END,
    },
)
workflow.add_conditional_edges(
    "file_type",
    lambda x: x.get("identified_type"),
    {
        "text/plain": "extract_txt",
        "application/pdf": "extract_pdf",
    },
)
workflow.add_conditional_edges(
    "url_provider",
    lambda x: x.get("identified_type"),
    {"article": "extract_url", "youtube": "extract_youtube_transcript"},
)
workflow.add_edge("url_provider", END)
workflow.add_edge("file_type", END)
workflow.add_edge("extract_txt", END)
workflow.add_edge("extract_pdf", END)
workflow.add_edge("extract_url", END)
workflow.add_edge("extract_youtube_transcript", END)
graph = workflow.compile()
