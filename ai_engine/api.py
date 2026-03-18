from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import pandas as pd
from recommendation_engine import RecommendationEngine

app = FastAPI(title="Movie Recommendation API")

# Modelo de entrada de datos
class MovieData(BaseModel):
    id: int
    titulo: str
    generos: str
    director: str
    descripcion: str

# Motor global (se inicializará con los datos cargados)
engine = None

@app.post("/update-movies")
async def update_movies(movies: List[MovieData]):
    """
    Actualiza el DataFrame de películas y reinicia el motor de recomendación.
    Útil cuando se agregan nuevas películas a la base de datos.
    """
    global engine
    try:
        df = pd.DataFrame([m.dict() for m in movies])
        engine = RecommendationEngine(df)
        return {"message": f"Motor de recomendación actualizado con {len(movies)} películas."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/recommendations/{movie_id}")
async def get_recommendations(movie_id: int, n: int = 5):
    """
    Obtiene las n recomendaciones para un ID de película dado.
    """
    if engine is None:
        raise HTTPException(status_code=400, detail="Motor no inicializado. Por favor actualiza los datos de películas.")

    try:
        recommendations = engine.obtener_recomendaciones(movie_id, n=n)
        return {"movie_id": movie_id, "recommendations": recommendations}
    except Exception as e:
        raise HTTPException(status_code=404, detail=f"No se pudo encontrar la película o generar recomendaciones: {str(e)}")

# Mock initialization (Opcional, para pruebas iniciales)
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
