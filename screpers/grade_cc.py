from bs4 import BeautifulSoup
import re
import json

padrao_codigo = re.compile(r'^[A-Z]{3}\d{4}$')
padrao_periodo = re.compile(r'(\d+)[ºo°]?\s*PER[IÍ]ODO', re.IGNORECASE)


def _tabela_curriculo_atual(tabelas):
    """
    Acha a tabela do currículo mais recente pelo rótulo (o que NÃO diz
    "anterior a XXXX"), em vez de assumir que é sempre a primeira da
    página — mais robusto se a ordem mudar no futuro.
    """
    for tabela in tabelas:
        rotulo_el = tabela.find_previous(['h1', 'h2', 'h3', 'h4', 'strong', 'b'])
        rotulo = rotulo_el.get_text(strip=True) if rotulo_el else ''
        if 'anterior' not in rotulo.lower():
            return tabela, rotulo
    return tabelas[0], None  # fallback


def extrair_periodo_curriculo_atual(html_content):
    """
    codigo -> periodo, usando só o currículo mais recente da página.
    Quando o mesmo código aparece em mais de um período (eletivas com
    intervalo de períodos), fica o menor.
    """
    soup = BeautifulSoup(html_content, 'html.parser')
    tabelas = soup.find_all('table', class_='ccg_tabela_periodizacao')
    tabela_atual, rotulo = _tabela_curriculo_atual(tabelas)

    periodo_atual = None
    mapeamento = {}

    for linha in tabela_atual.find_all('tr'):
        colunas = linha.find_all('td')
        if not colunas:
            continue

        # Linha de cabeçalho de período: só 1 <td> (ex: "1º PERÍODO")
        if len(colunas) == 1:
            texto = colunas[0].get_text().replace('\xa0', '').strip()
            match_periodo = padrao_periodo.search(texto)
            if match_periodo:
                periodo_atual = int(match_periodo.group(1))
            continue

        # Linha de disciplina: código na primeira coluna
        codigo = colunas[0].get_text().replace('\xa0', '').strip()
        if padrao_codigo.match(codigo) and periodo_atual is not None:
            if codigo not in mapeamento or periodo_atual < mapeamento[codigo]:
                mapeamento[codigo] = periodo_atual

    return dict(sorted(mapeamento.items())), rotulo


def extrair_todos_codigos(html_content):
    """
    Todos os códigos únicos entre os 3 currículos da página (sem se
    importar com período) — pro 'universo' de disciplinas que o outro
    scraper usa pra buscar nome/dependências.
    """
    soup = BeautifulSoup(html_content, 'html.parser')
    tabelas = soup.find_all('table', class_='ccg_tabela_periodizacao')

    codigos = set()
    for tabela in tabelas:
        for linha in tabela.find_all('tr'):
            colunas = linha.find_all('td')
            if not colunas:
                continue
            codigo = colunas[0].get_text().replace('\xa0', '').strip()
            if padrao_codigo.match(codigo):
                codigos.add(codigo)

    return sorted(codigos)


if __name__ == "__main__":
    caminho_html = "screpers/grade_cc.html"

    with open(caminho_html, "r", encoding="utf-8") as file:
        html = file.read()

    todos_codigos = extrair_todos_codigos(html)
    periodos, rotulo_curriculo = extrair_periodo_curriculo_atual(html)

    with open("screpers/lista_materias.json", "w", encoding="utf-8") as file:
        json.dump(todos_codigos, file, ensure_ascii=False, indent=4)

    with open("screpers/periodos_curriculo_atual_cc.json", "w", encoding="utf-8") as file:
        json.dump(periodos, file, ensure_ascii=False, indent=4)

    print(f"{len(todos_codigos)} códigos únicos (todos os currículos) salvos em 'lista_materias.json'.")
    print(f"Currículo usado pro período: '{rotulo_curriculo}'")
    print(f"{len(periodos)} matérias com período salvas em 'periodos_curriculo_atual_cc.json'.")