# tema.R -------------------------------------------------------------------
# Tema do artigo "destino do lixo" (Censo 2022). CANONICO aqui, em
# destino-do-lixo/R/tema.R; o site carrega uma COPIA identica em
# quarto/_temas/lixo.R. Editar aqui e copiar -- R/03_exportar_site.R faz isso.
#
# Molde: quarto/_temas/anuario.R (ggiraph, nao plotly -- o mapa e o grafico de
# pontos sao ggplot e precisam chegar com subtitulo e fonte intactos).
# Cores, tintas e tabela vem do theoviz (>= 0.3.1), sempre no modo escuro: o
# artigo vai ao ar na pagina escura do site. Nao defina cor literal aqui, com
# uma excecao documentada abaixo (a rampa do mapa).

library(ggplot2)
suppressPackageStartupMessages(library(theoviz))
# LARGURA_SVG e ajustar_textos(). No site o arquivo mora em quarto/_temas/
# (comum aos temas com ggiraph); no projeto, em R/. Mesma regra do dados().
source(Find(file.exists, file.path(here::here(), c("_temas", "R"), "girafe_celular.R")))

# O mesmo arquivo roda nos dois lugares: no site os dados moram em
# quarto/_dados/lixo/ (here::here() resolve para <site>/quarto); no projeto,
# em dados/.
dados <- function(arq) {
  no_site <- file.path(here::here(), "_dados", "lixo", arq)
  if (file.exists(no_site)) no_site else file.path(here::here(), "dados", arq)
}

.p <- paleta(modo = "escuro")
.t <- tinta(modo = "escuro")
PAL <- c(s1 = unname(.p[["s1"]]), s2 = unname(.p[["s2"]]),
         s3 = unname(.p[["s3"]]), s4 = unname(.p[["s4"]]))
TINTA      <- unname(.t[["forte"]])
TINTA_2    <- unname(.t[["media"]])
TINTA_MUDA <- unname(.t[["fraca"]])
GRADE      <- unname(.t[["grade"]])
EIXO       <- unname(.t[["eixo"]])
FUNDO      <- site("noite")

# Rampa ordinal do mapa: cinco passos de UM tom (o azul do s1 -- #3987e5 e o
# passo 400 da mesma escala), do escuro (pouco) ao claro (muito), porque no
# fundo escuro mais magnitude e mais contraste com a pagina. O theoviz ainda
# nao tem rampa sequencial (pendencia registrada no STATUS do site); estes
# passos sao os da escala azul de referencia do skill dataviz, validados em
# 2026-11-01 com
#   node scripts/validate_palette.js "#184f95,#256abf,#3987e5,#6da7ec,#b7d3f6" \
#        --ordinal --mode dark --surface "#0d1014"      -> ALL CHECKS PASS (2,35:1)
#   ... --surface "#141920" (chapa)                       -> ALL CHECKS PASS (2,18:1)
#   ... --mode light --surface "#ffffff"                  -> FAIL na ponta clara
# O artigo so existe sobre fundo escuro; num fundo claro a rampa teria de ser
# invertida e revalidada. Quando o theoviz ganhar a rampa, trocar por ela.
RAMPA <- c("#184f95", "#256abf", "#3987e5", "#6da7ec", "#b7d3f6")

tema_lixo <- function(base_size = 11) {  # 11, nao 12: ver girafe_celular.R
  theme_minimal(base_size = base_size) +
    theme(
      text             = element_text(colour = TINTA_2),
      plot.title       = element_text(colour = TINTA, face = "bold",
                                      size = rel(1.15), margin = margin(b = 4)),
      plot.subtitle    = element_text(colour = TINTA_2, size = rel(0.92),
                                      margin = margin(b = 12)),
      plot.caption     = element_text(colour = TINTA_MUDA, size = rel(0.78),
                                      hjust = 0, margin = margin(t = 12)),
      plot.title.position   = "plot",
      plot.caption.position = "plot",
      axis.text        = element_text(colour = TINTA_MUDA, size = rel(0.85)),
      axis.title       = element_text(colour = TINTA_MUDA, size = rel(0.85)),
      panel.grid.major = element_line(colour = GRADE, linewidth = 0.3),
      panel.grid.minor = element_blank(),
      legend.position  = "none",
      plot.margin      = margin(6, 12, 6, 6)
    )
}
theme_set(tema_lixo())

FONTE <- paste0("Fonte: IBGE, Censo Demográfico 2022, agregados por setor censitário, ",
                "lidos com o pacote censobr (Ipea).")
FONTE_MAPA <- paste0(FONTE, "\nMalha municipal 2022 via geobr (Ipea).")

# Graficos interativos: ggiraph. Mesmas opcoes do anuario.R -- o tooltip usa a
# CHAPA do site, nao a tinta de texto (ver o comentario la).
interativo <- function(p, altura = 4.2, largura = LARGURA_SVG, realce = TRUE) {
  ggiraph::girafe(
    ggobj = ajustar_textos(p, largura), width_svg = largura, height_svg = altura, bg = "transparent",
    options = list(
      if (realce) ggiraph::opts_hover(css = paste0("stroke:", TINTA, ";stroke-width:1.2;"))
      else ggiraph::opts_hover(css = ""),
      ggiraph::opts_hover_inv(css = if (realce) "opacity:0.55;" else ""),
      ggiraph::opts_tooltip(
        css = paste0(
          "background:", site("chapa"), ";color:", site("titulo"), ";",
          "border:1px solid ", site("filete"), ";padding:7px 10px;",
          "border-radius:0;font-family:'IBM Plex Sans',system-ui,sans-serif;",
          "font-size:12.5px;line-height:1.45;"
        ),
        opacity = 1, use_fill = FALSE
      ),
      ggiraph::opts_toolbar(saveaspng = FALSE),
      ggiraph::opts_sizing(rescale = TRUE, width = 1)
    )
  )
}

# O mapa tem 5.570 poligonos e o svglite escreve cada coordenada com seis
# casas: o widget passava de 6 MB. So os caminhos (atributo d= dos <path>) sao
# reescritos: coordenada truncada ao pixel inteiro e sem espaco em volta do
# L. Vizinhos compartilham vertices, entao truncam igual e nao abrem fresta;
# num SVG de ~540 px o degrau de 1 px nao se ve num mapa sem contorno. Medido em
# 2026-11-01. Aplicar so a figura com muita geometria.
#
# Corta o texto nas aspas simples (o svglite so usa ' nos atributos): o pedaco
# que vem depois de um " d=" e o conteudo de um caminho. Vetorizado de
# proposito -- `regmatches<-` sobre 5.570 trechos de uma string de 6 MB copia a
# string a cada troca e travou o render.
enxuga_svg <- function(w) {
  partes <- strsplit(w$x$html, "'", fixed = TRUE)[[1]]
  i <- which(endsWith(partes, " d="))
  if (length(i)) {
    d <- partes[i + 1]
    d <- gsub("([0-9]+)[.][0-9]+", "\\1", d, perl = TRUE)  # trunca ao pixel
    d <- gsub(" ?([ML]) ", "\\1", d, perl = TRUE)
    # truncado, um vertice costuma repetir o anterior: fica um so
    partes[i + 1] <- gsub("(L[0-9]+ [0-9]+)(?:\\1)+", "\\1", d, perl = TRUE)
  }
  w$x$html <- paste(partes, collapse = "'")
  w
}

# Numeros pt-BR para prosa e tooltip: num_br() do theoviz, mais dois atalhos.
pct <- function(x, dec = 1) paste0(num_br(100 * x, dec), "%")   # x em 0-1
mi  <- function(x, dec = 1) paste(num_br(x / 1e6, dec), "milhões")

# Tabelas: o tema canonico do theoviz, sempre em modo escuro (sem ele o gt
# crava background branco inline).
tabela <- function(x, ...) tabela_gt(x, ..., modo = "escuro")
