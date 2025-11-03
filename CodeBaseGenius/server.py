from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
import jacin

app = FastAPI(title="Codebase Genius API")

class Request(BaseModel):
    repo_url: str

@app.post("/genius/analyze")
async def analyze_repo(req: Request):
    walker = jacin.Walker("code_genius")
    result = walker.execute(repo_url=req.repo_url)
    return result

@app.get("/genius/documentation")
async def get_docs():
    walker = jacin.Walker("get_documentation")
    result = walker.execute()
    if "error" in result:
        raise HTTPException(404, result["error"])
    return result

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)