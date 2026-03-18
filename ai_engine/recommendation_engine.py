import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer, CountVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np

class RecommendationEngine:
    def __init__(self, df):
        """
        Inicializa el motor con un DataFrame que contiene:
        id, titulo, generos, director, descripcion
        """
        self.df = df
        self._prepare_data()

    def _prepare_data(self):
        # Limpieza básica
        self.df['descripcion'] = self.df['descripcion'].fillna('')
        self.df['generos'] = self.df['generos'].fillna('')
        self.df['director'] = self.df['director'].fillna('')

        # 1. TF-IDF para las descripciones (captura importancia de palabras clave)
        tfidf = TfidfVectorizer(stop_words='english')
        tfidf_matrix = tfidf.fit_transform(self.df['descripcion'])

        # 2. CountVectorizer para géneros y director (importancia directa de etiquetas)
        # Combinamos géneros y director en un solo "soup" de palabras clave
        self.df['metadata'] = self.df.apply(lambda x: f"{x['generos']} {x['director']}", axis=1)
        count_vec = CountVectorizer(stop_words='english')
        count_matrix = count_vec.fit_transform(self.df['metadata'])

        # 3. Combinar ambas matrices (le damos un peso similar o ajustado)
        # Usamos hstack para combinar las características
        from scipy.sparse import hstack
        self.combined_matrix = hstack([tfidf_matrix, count_matrix])

        # 4. Calcular Similitud del Coseno
        self.cosine_sim = cosine_similarity(self.combined_matrix, self.combined_matrix)

    def obtener_recomendaciones(self, titulo_o_id, n=5):
        # Buscar el índice por ID o por Título
        if isinstance(titulo_o_id, int) or str(titulo_o_id).isdigit():
            idx = self.df.index[self.df['id'] == int(titulo_o_id)].tolist()
        else:
            idx = self.df.index[self.df['titulo'].str.contains(titulo_o_id, case=False)].tolist()

        if not idx:
            return []

        idx = idx[0]

        # Obtener puntuaciones de similitud
        sim_scores = list(enumerate(self.cosine_sim[idx]))

        # Ordenar por similitud (descendente)
        sim_scores = sorted(sim_scores, key=lambda x: x[1], reverse=True)

        # Tomar los N más similares (excluyendo el propio elemento en el índice 0)
        sim_scores = sim_scores[1:n+1]

        # Obtener los índices de las películas
        movie_indices = [i[0] for i in sim_scores]

        # Retornar los resultados como lista de diccionarios
        return self.df.iloc[movie_indices][['id', 'titulo', 'generos', 'director']].to_dict(orient='records')

# Ejemplo de uso rápido (Mock data)
if __name__ == "__main__":
    data = {
        'id': [1, 2, 3, 4, 5],
        'titulo': ['The Dark Knight', 'Inception', 'Interstellar', 'The Godfather', 'Batman Begins'],
        'generos': ['Action Crime Drama', 'Action Adventure Sci-Fi', 'Adventure Drama Sci-Fi', 'Crime Drama', 'Action Adventure'],
        'director': ['Christopher Nolan', 'Christopher Nolan', 'Christopher Nolan', 'Francis Ford Coppola', 'Christopher Nolan'],
        'descripcion': [
            'Batman fights the Joker in Gotham.',
            'A thief steals secrets through dream-sharing technology.',
            'A team of explorers travel through a wormhole in space.',
            'The aging patriarch of an organized crime dynasty transfers control to his reluctant son.',
            'Batman starts his journey to save Gotham.'
        ]
    }
    df_movies = pd.DataFrame(data)
    engine = RecommendationEngine(df_movies)
    print("Recomendaciones para 'The Dark Knight':")
    print(engine.obtener_recomendaciones('The Dark Knight'))
