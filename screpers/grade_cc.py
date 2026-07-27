from bs4 import BeautifulSoup
import re
import json

def extract_curriculum_CC(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')

    # Regex para identificar o padrão exato de matérias da PUC (Ex: INF1005, MAT4202)
    # ^ indica o começo da string, [A-Z]{3} são 3 letras, \d{4} são 4 números, $ indica o fim.
    padrao_codigo = re.compile(r'^[A-Z]{3}\d{4}$')

    # Usa SET ao invés de lista para evitar duplicatas
    materias = set()

    # Busca todas as tabelas que contem as grades
    tabelas = soup.find_all('table', class_="ccg_tabela_periodizacao")

    for tabela in tabelas:
        linhas = tabela.find_all('tr')

        for linha in linhas:
            colunas = linha.find_all('td')

            if colunas:
                # O código sempre fica na primeira coluna (índice 0)
                codigo_bruto = colunas[0].text

                # Limpa espaços em branco e caracteres invisíveis do HTML (como o &nbsp;)
                codigo_limpo = codigo_bruto.replace('\xa0', '').strip()

                # Verifica se o texto extraído bate com a regra do Regex
                if padrao_codigo.match(codigo_limpo):
                    materias.add(codigo_limpo)

        # Converte o set de volta para lista ordenada alfabeticamente
        lista_final = list(materias)
        lista_final.sort()

        return lista_final
    

if __name__ == "__main__":
    caminho_html = "screpers/grade_cc.html"
    caminho_lista = "screpers/lista_materias.json"
    
    try:
        with open(caminho_html, "r", encoding="utf-8") as file:
            html = file.read()

        materias_extraidas = extract_curriculum_CC(html)
        
        # salva a lista gerada em um arquivo JSON
        with open(caminho_lista, "w", encoding="utf-8") as file:
            json.dump(materias_extraidas, file, ensure_ascii=False, indent=4)

        print(f"Lista de matérias extraídas e salva em '{caminho_lista}' com sucesso.")

    except FileNotFoundError:
        print("Arquivo 'grade_cc.html' não encontrado. Certifique-se de que o arquivo está no mesmo diretório do script.")