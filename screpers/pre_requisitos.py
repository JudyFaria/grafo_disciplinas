import requests
from bs4 import BeautifulSoup

import json
import time

from pathlib import Path

def get_subject_data(code):

    '''
        Acessa a página da ementa de matéria e extrai as informações.
    '''

    url = f"https://www.puc-rio.br/ferramentas/ementas/ementa.aspx?cd={code}"

    # cabeçalho (User-Agent) para simular um navegador real 
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }

    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()  # verifica se a requisição foi bem-sucedida

        soup = BeautifulSoup(response.content, 'html.parser')

        # Captura o nome da disciplina
        nome_elemento = soup.find('span', id='hTitulo')
        nome = nome_elemento.text.strip() if nome_elemento else "Nome não encontrado"

        # Captura os pré-requisitos
        pre_requisitos = []
        fieldset_prereq = soup.find('fieldset', id="prerequisito")
        
        if fieldset_prereq:
            # O site da PUC agrupa cada condição "OU" dentro de um <span class="links">
            blocos_ou = fieldset_prereq.find_all('span', class_='links')

            for bloco in blocos_ou:
                condicoes_e = []

                # procura por links (materias normais) dentro do bloco
                links = bloco.find_all('a')
                
                if links:
                    # Extrai apenas o texto do link (ex: "MAT1250")
                    condicoes_e = [link.text.strip() for link in links]
                
                else:
                    # extrai o texto bruto do bloco, que pode conter condições "OU" sem links
                    texto_condicao = bloco.text.strip()
                    if texto_condicao:
                        condicoes_e.append(texto_condicao)  

                if condicoes_e:
                    pre_requisitos.append(condicoes_e)
                    
        # Captura os Co-requisitos
        co_requisitos = []
        fieldset_coreq = soup.find('fieldset', id="corequisito")
        if fieldset_coreq:
            links_coreq = fieldset_coreq.find_all('a')
            co_requisitos = [link.text.strip() for link in links_coreq]

        return{
            "nome": nome,
            "pre_requisitos": pre_requisitos,
            "co_requisitos": co_requisitos
        }
    
    except requests.exceptions.RequestException as e:
        print(f"Erro ao acessar a página da disciplina {code}: {e}")
        return None
    



def main():
    
    print("Iniciando scraper de pré-requisitos...")

    caminho_lista = Path("screpers/lista_materias.json")
    caminho_saida = Path("dados_materias.json")

    # carrega a lista gerada
    try:
        with open(caminho_lista, "r", encoding="utf-8") as file:
            materias_cc = json.load(file)
    except FileNotFoundError:
        print("Arquivo 'listas_materias.json' não encontrado.")
        return

    # dicionário para armazenar os dados das matérias
    dados_materias = {}

    # executa as requisições  
    for code in materias_cc:
        print(f"Buscando: {code}")
        dados = get_subject_data(code)
        
        if dados:
            dados_materias[code] = dados
        
        time.sleep(2)  # Pausa de 2 segundos entre as requisições para não sobrecarregar o servidor

    with open(caminho_saida, 'w', encoding='utf-8') as f:
        json.dump(dados_materias, f, ensure_ascii=False, indent=4)

    print("\nScraping concluído. Dados salvos em 'dados_materias.json'.")

if __name__ == "__main__":
    main()