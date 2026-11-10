# girafe_celular.R ----------------------------------------------------------
# Medida comum dos graficos ggiraph. Lido por R/tema.R -- nao por um .qmd
# direto. Copia de quarto/_temas/girafe_celular.R do repo do site
# (theoalbuquerque-site), trazida para este repo funcionar sozinho. NAO vai ao
# site pelo R/03_exportar_site.R: la o arquivo ja existe e e comum a outros
# temas. Mudou a medida? Mude nos dois.
#
# POR QUE 5 POLEGADAS (2026-11-09) ---------------------------------------------
# O ggiraph escreve o SVG com viewBox de `width_svg` x 72 unidades, e o texto em
# pontos dessas unidades. O SVG encolhe ate caber na coluna; a 390 px de tela a
# coluna tem ~340 px. Com width_svg = 8 (576 unidades) o fator era 0,59, e o
# texto do eixo, de 10 pt, chegava ao celular com 6 px. Com 5 polegadas (360
# unidades) o fator e 0,94: o mesmo texto chega com ~9 px. No computador, o
# artigo.css limita .girafe a 640 px (fator 1,78), para o texto nao inchar.
#
# Os temas descem o base_size de 12 para 11 junto: num quadro mais estreito, o
# texto ocupa mais da largura. Eixo a 11 x 0,85 = 9,35 pt -> ~8,8 px a 340 px e
# ~16,6 px a 640 px.
LARGURA_SVG <- 5

# Titulo, subtitulo e legenda do grafico eram escritos para 8 polegadas e numa
# linha so. A 5, a linha da fonte saia da caixa. Em vez de cravar "\n" em cada
# .qmd, a quebra e calculada aqui, com a metrica da fonte que o svglite usa
# (Liberation Sans; no Windows o systemfonts cai na Arial, de metrica identica).
.medir_pt <- function(s, pt, negrito) {
  systemfonts::string_width(s, family = "Liberation Sans", size = pt, res = 72,
                            weight = if (negrito) "bold" else "normal")
}

.quebrar <- function(txt, pt, largura_pt, negrito = FALSE) {
  paragrafos <- strsplit(txt, "\n", fixed = TRUE)[[1]]
  linhas <- unlist(lapply(paragrafos, function(par) {
    palavras <- strsplit(par, " ", fixed = TRUE)[[1]]
    saida <- character(); atual <- ""
    for (w in palavras) {
      cand <- if (nzchar(atual)) paste(atual, w) else w
      if (nzchar(atual) && .medir_pt(cand, pt, negrito) > largura_pt) {
        saida <- c(saida, atual); atual <- w
      } else atual <- cand
    }
    c(saida, atual)
  }))
  paste(linhas, collapse = "\n")
}

.pt <- function(u) {
  as.numeric(grid::convertWidth(u, "pt", valueOnly = TRUE))
}

# Quebra title/subtitle/caption na largura util do SVG. Texto em `labs()` que
# nao seja string (expressao, NULL, waiver) passa intacto.
ajustar_textos <- function(p, largura = LARGURA_SVG) {
  th <- ggplot2::complete_theme(p$theme)
  m  <- .pt(th$plot.margin)               # cima, direita, baixo, esquerda
  util_plot <- largura * 72 - m[2] - m[4] - 2
  novos <- list()
  for (campo in c("title", "subtitle", "caption")) {
    txt <- p$labels[[campo]]
    if (!is.character(txt) || length(txt) != 1 || !nzchar(txt)) next
    el <- ggplot2::calc_element(paste0("plot.", campo), th)
    pos <- if (campo == "caption") th$plot.caption.position else th$plot.title.position
    # posicao "panel": o texto comeca depois do eixo y; desconta uma margem.
    util <- if (identical(pos, "plot")) util_plot else util_plot - 40
    negrito <- identical(el$face, "bold")
    novos[[campo]] <- .quebrar(txt, el$size, util, negrito)
  }
  if (length(novos)) p <- p + do.call(ggplot2::labs, novos)
  p
}
