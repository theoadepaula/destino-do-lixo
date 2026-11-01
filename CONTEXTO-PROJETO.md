# Contexto do projeto — Para onde vai o lixo dos domicílios (Censo 2022)

> Ponto de entrada do projeto. O [`README.md`](README.md) diz como rodar; **este
> arquivo é o porquê** — decisões, correções da exploração e o que está pendente.
> Criado em 2026-11-01 a partir do projeto 1 de `~/dev/explora-pacotes-br/`.

---

## 1. O que é

Destino do lixo dos domicílios brasileiros, **por município**, com os agregados
por setor censitário do **Censo 2022** lidos pelo `censobr` e a malha do IBGE
lida pelo `geobr` — os dois do Ipea (Rafael H. M. Pereira), catálogo brverse.
Alimenta **um artigo** no site e, numa etapa futura, **um painel** (§6).

- Artigo: `theoalbuquerque-site/quarto/posts/lixo-queimado-censo-2022/index.qmd`
  ("Um em cada catorze domicílios do Brasil queima o próprio lixo"), agendado
  para **2027-02-17** — data provisória, o Théo decide na revisão.
- Valor de portfólio: dado tirado direto da fonte e reproduzível em poucas
  linhas (seção "Como reproduzir" do artigo).

⚠️ **Lei 840.** O Théo trabalha no SLU-DF. Aqui o DF é só mais uma UF no dado do
Censo. Nada sobre contrato, empresa ou operação do SLU, no artigo ou no painel.

---

## 2. Estrutura

| Caminho | O que é |
|---|---|
| `R/01_censo.R` | `censobr` → setores → município. Gera os três parquets de `dados/` |
| `R/02_malha.R` | `geobr` → malha 2022 (municípios) e 2020 (UFs), simplificada a 3% com `rmapshaper`, 3 casas decimais |
| `R/03_exportar_site.R` | Copia retratos + malha para `site/quarto/_dados/lixo/` e o tema para `site/quarto/_temas/lixo.R` |
| `R/04_retrato_painel.R` | Retrato enxuto para o painel (`painel_muni_lixo.parquet`/`.csv`) |
| `R/tema.R` | **Canônico** do tema do artigo. A cópia do site é idêntica — editar aqui e rodar o 03 |
| `dados/cache_censobr/` | Cache do `censobr` (289 MB: domicílio, pessoas, básico, dicionário). Fora do git |
| `dados/SNAPSHOT` | Versões dos pacotes e do data release, com a data da leitura |

Conferência da prosa: `site/quarto/posts/lixo-queimado-censo-2022/_conferir_prosa.R`
(no padrão dos posts do site). **Rodar depois de qualquer mudança no 01.**

---

## 3. Decisões

- **Denominador = soma dos seis destinos publicados**, não o total de domicílios
  (`V00001`). As partes somam 100% e a lacuna de sigilo fica dita em texto, não
  preenchida. A diferença entre os dois denominadores é de 0,4%.
- **Esgoto usa o próprio total.** O sigilo corta cada tabela por conta própria;
  lixo e esgoto não somam igual por município (5.418 municípios diferem).
- **Rural/urbano pela situação do setor** (`situacao` do `censobr`). É o corte
  que mais explica a queima: 11,5% dos domicílios, 92,2% da queima.
- **A correlação com o esgoto (−0,53) entra com a parcial (−0,16).** Sem ela, o
  texto sugeriria um vínculo que é sobretudo o campo.
- **Cor ou raça entrou, com padronização.** O dado sustenta: cobertura de 95,5%
  (indígena) a 99,2% (branca) contra o total de responsáveis da tabela de
  pessoas. A taxa de cada grupo é comparada com a que teria se queimasse como os
  domicílios de responsável branco **do mesmo município e situação**. O lugar
  explica 92% (pardos), 84% (pretos) e 80% (indígenas) da diferença. Texto
  cuidadoso: mede onde o serviço não chega, não comportamento; resíduo não é
  causa.
- **Mapa em `ggiraph`**, tooltip por município. O SVG saía com 6,4 MB;
  `enxuga_svg()` (em `R/tema.R`) trunca as coordenadas dos `<path>` ao pixel e tira vértices repetidos: 1,7 MB.
  O gráfico de dispersão (5.570 pontos) é **estático**: com tooltip pesava 1,9 MB
  e o mapa já responde "e o meu município?".
- **Rampa do mapa**: cinco passos de azul (família do `s1` do theoviz), validados
  com o validador do skill `dataviz` em modo escuro (passa contra `noite` e
  `chapa`; falha no claro, onde o artigo não existe). O theoviz ainda não tem
  rampa sequencial — quando tiver, trocar.

---

## 4. Correções à exploração (conferidas em 2026-11-01)

| Achado da exploração | Conferido |
|---|---|
| 7,06% queimam (5,1 mi de 72,1 mi) | ✅ 5.096.143 de 72.144.180 |
| 294 municípios > 50%, topo Bacurituba (MA) 86% | ✅ 1.485 de 1.725, 86,1% |
| MA 25,8% × 0,6% no DF e em SP | ✅ (SP 0,65%, DF 0,64%) |
| correlação −0,53 queima × esgoto em rede | ✅, mas a parcial descontando o rural é −0,16 |
| **22.606 setores com dado suprimido** | ❌ **Errado.** Contava `V00397` = NA. São **8.684** setores inteiros sem dado (20.228 domicílios no Básico) **mais** 13.922 setores em que a coleta tinha 1 ou 2 domicílios — sigilo de célula, não de setor |
| — (bug da 1ª versão do 01) | A taxa rural saía > 100%: dentro do `summarise`, o `across()` já tinha trocado `dom_queimado` pela soma. As colunas rurais agora nascem no setor |

**Regra do sigilo, medida:** setor muito pequeno sai inteiro; nos demais, toda
contagem de 1 ou 2 vira NA (o menor positivo publicado é 3). Isso tira 294.773
domicílios da quebra por destino e mais ainda da quebra por cor (30 células por
setor em vez de 6).

---

## 5. Achados (todos testados no `_conferir_prosa.R`)

1. 7,1% dos domicílios (5,1 mi; 15,9 mi de moradores) queimam o lixo; 91,9% têm coleta ou caçamba.
2. Campo: 56,5% queimam; cidade: 0,6%. Setores rurais = 11,5% dos domicílios, 92,2% da queima.
3. MA 25,8%, PI 24,1%, PA 20,3% … RJ 0,8%, SP e DF 0,6%. MA/SP ≈ 40×. N+NE: 33,1% dos domicílios, 71,4% da queima. BA é a maior em número absoluto (743 mil).
4. 1.223 municípios > 30%; 294 > 50% (268 deles de maioria rural; MA 65, PI 61). Mediana de 3.515 domicílios; somam 14,7% da queima.
5. Esgoto: −0,53 (parcial −0,16). Até 10% de rede: 27,3% queimam; mais de 90%: 0,4%.
6. Cor ou raça do responsável: indígena 50,7%, parda 9,6%, preta 6,9%, branca 4,0%.

---

## 6. O painel (próxima etapa — não feito)

Retrato pronto: `dados/painel_muni_lixo.parquet` (261 KB; `.csv` 539 KB) +
`dados/muni_2022_k03_d3.geojson` (4,4 MB; ~1 MB em gzip) + `dados/uf_2020_k03_d3.geojson`.
Junção por `code_muni`. Painel no navegador (stlite ou Shinylive), sem servidor.

O que deveria mostrar:
- **Busca do município** → cartão com a distribuição dos seis destinos, parte
  rural e esgoto em rede, comparados com a UF e o Brasil.
- **Mapa** com seletor de indicador (queima, coleta, esgoto em rede, parte
  rural), na mesma rampa do artigo; filtro por UF que dá zoom.
- **Tabela ordenável** dos municípios da UF escolhida (é o par textual do mapa).
- Nota fixa sobre o sigilo (`lacuna_sigilo` por município) e a fonte.
- Não repetir o recorte por cor no painel sem a padronização ao lado — sozinho,
  ele convida à leitura errada.

---

## 7. Pendências

- [ ] Revisão do Théo no artigo e decisão da data.
- [ ] Repositório público `theoadepaula/destino-do-lixo`: git local com o 1º commit (2026-11-01); falta `gh repo create theoadepaula/destino-do-lixo --public --source . --push`. O rodapé do artigo já aponta para ele.
- [ ] Painel (§6).
- [ ] Trocar a rampa do mapa pela do theoviz quando existir.
- [ ] Pauta possível, não escrita: comparar com 2010 exige compatibilizar setores.
