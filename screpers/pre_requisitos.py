import requests
from bs4 import BeautifulSoup

import json
import time
import re

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

        # "Grupo de Disciplinas" -- aparece em optativas/eletivas/extensão
        # no lugar de pré-requisito: é uma lista de matérias concretas que
        # valem como opção pra essa "vaga".
        grupo_disciplinas = []
        cabecalho_grupo = soup.find(
            lambda tag: tag.name in ('legend', 'h2', 'h3', 'b', 'strong')
            and 'grupo de disciplinas' in tag.get_text(strip=True).lower()
        )
        if cabecalho_grupo:
            container = cabecalho_grupo.find_parent('fieldset') or cabecalho_grupo.find_parent()
            if container:
                for link in container.find_all('a'):
                    codigo_opcao = link.get_text(strip=True)
                    if not codigo_opcao:
                        continue
                    nome_opcao = link.find_next(string=True)
                    nome_opcao = nome_opcao.strip() if nome_opcao else ''
                    grupo_disciplinas.append({'codigo': codigo_opcao, 'nome': nome_opcao})

        # Créditos: aparece como "N créditos" logo abaixo do título
        creditos = None
        match_creditos = re.search(r'(\d+)\s*cr[ée]dito', soup.get_text())
        if match_creditos:
            creditos = int(match_creditos.group(1)) 
            
        return{
            "nome": nome,
            "pre_requisitos": pre_requisitos,
            "co_requisitos": co_requisitos,
            "grupo_disciplinas": grupo_disciplinas,
            "creditos": creditos,
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
    codigos_pendentes = list(materias_cc) 
    codigos_processados = set()

    while codigos_pendentes:
        code = codigos_pendentes.pop(0)
        if code in codigos_processados:
            continue  # já processado, pula para o próximo

        codigos_processados.add(code)

        print(f"Buscando: {code}")
        dados = get_subject_data(code)

        if dados:
            dados_materias[code] = dados
            for opcao in dados.get('grupo_disciplinas', []):
                codigo_opcao = opcao['codigo'].strip().upper()
                if codigo_opcao and codigo_opcao not in codigos_processados:
                    codigos_pendentes.append(codigo_opcao)

        time.sleep(2)
    
    with open(caminho_saida, 'w', encoding='utf-8') as f:
        json.dump(dados_materias, f, ensure_ascii=False, indent=4)

    print("\nScraping concluído. Dados salvos em 'dados_materias.json'.")

if __name__ == "__main__":
    main()