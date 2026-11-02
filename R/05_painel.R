# 05_painel.R ------------------------------------------------------------------
# Monta o painel do site (CONTEXTO-PROJETO.md §6) em
# <site>/public/apps/destino-do-lixo/: HTML autocontido + malha em JSON.
#
# Mesmo idioma dos outros painéis do site (cargos-executivo-federal,
# relatorios-slu): HTML com os dados embutidos, mapa em SVG desenhado à mão,
# nenhum script externo. Sem webR/Pyodide: o mapa de 5.570 polígonos chega em
# ~400 KB comprimidos na primeira tela, em vez das dezenas de MB de um runtime WASM.
#
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" R/05_painel.R
#
# NÃO edite o index.html gerado: edite painel/modelo.html e rode este script.
#
# A malha sai PRÉ-PROJETADA, como o atributo d= de cada <path> em SVG, para o
# navegador só pendurar a string (decodificar 125 mil vértices em JS custava
# ~3 s num celular lento, medido em 2026-11-01):
#   malha/br.json      Brasil inteiro, numa moldura de 1.200 de largura
#   malha/uf-XX.json   uma UF, numa moldura de pelo menos 1.600 (e unidade de
#                      no máximo 0,002°), baixada só quando a UF é escolhida
# Projeção equirretangular com x * cos(latitude média da moldura). Coordenadas
# inteiras, comandos relativos (l), vértices repetidos depois de arredondar
# removidos. Vizinhos arredondam igual, então não abre fresta entre eles.

suppressMessages({library(dplyr); library(arrow); library(sf); library(jsonlite)})
RAIZ <- normalizePath(".", winslash = "/")
stopifnot(file.exists(file.path(RAIZ, "CONTEXTO-PROJETO.md")))
SITE <- Sys.getenv("SITE_RAIZ", file.path(dirname(RAIZ), "theoalbuquerque-site"))
stopifnot(dir.exists(SITE))
SAIDA <- file.path(SITE, "public", "apps", "destino-do-lixo")
dir.create(file.path(SAIDA, "malha"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(SAIDA, "fontes"), recursive = TRUE, showWarnings = FALSE)
sf_use_s2(FALSE)

# -- dados por município ---------------------------------------------------------
m <- read_parquet(file.path(RAIZ, "dados", "censo2022_muni_lixo.parquet")) |>
  arrange(code_muni)
stopifnot(nrow(m) == 5570, all(m$rur_queimado <= m$rur_total))

# Colunas, não objetos: 5.570 linhas × 18 números. O JS calcula as taxas.
# Do lado rural vêm queima, coleta (coletado + caçamba) e esgoto; o urbano é
# o total menos o rural.
mun <- list(
  c   = m$code_muni, n = m$name_muni, u = m$uf,
  dom = m$dom_total, col = m$dom_coletado, cac = m$dom_cacamba,
  que = m$dom_queimado, ent = m$dom_enterrado, bal = m$dom_baldio,
  out = m$dom_outro, morq = m$mor_queimado,
  rt  = m$rur_total, rq = m$rur_queimado, rc = m$rur_coleta,
  et  = m$esg_total, er = m$esg_rede, ret = m$rur_esg_total, rer = m$rur_esg_rede,
  lac = m$lacuna_celula
)
stopifnot(all(m$rur_coleta <= m$rur_total), all(m$rur_esg_rede <= m$rur_esg_total))
mun[setdiff(names(mun), c("c", "n", "u"))] <-
  lapply(mun[setdiff(names(mun), c("c", "n", "u"))], function(x) as.integer(round(x)))

ufs <- m |> distinct(code_state, uf, name_state, name_region) |> arrange(name_state)

# -- malha -----------------------------------------------------------------------
# W = largura mínima da moldura; `grau` = maior tamanho, em graus, de uma
# unidade da moldura. O painel aproxima até 12× numa UF: com 1.600 unidades fixas,
# MG (11° de largura) virava escada de pixels. Com uma unidade de no máximo
# 0,002° (~200 m, o dobro da precisão do GeoJSON) o contorno segue liso.
moldura <- function(g, W, grau = Inf) {
  b <- st_bbox(g); k <- cos(mean(c(b[["ymin"]], b[["ymax"]])) * pi / 180)
  W <- max(W, ceiling((b[["xmax"]] - b[["xmin"]]) * k / grau))
  s <- W / ((b[["xmax"]] - b[["xmin"]]) * k)
  list(x0 = b[["xmin"]], y1 = b[["ymax"]], k = k, s = s, W = W,
       H = ceiling((b[["ymax"]] - b[["ymin"]]) * s))
}
codifica <- function(g, ids, mo) {
  xy <- st_coordinates(g)
  # MULTIPOLYGON: L1 anel, L2 polígono, L3 feição; POLYGON: L1 anel, L2 feição
  lv <- intersect(c("L1", "L2", "L3"), colnames(xy))
  fe <- xy[, lv[length(lv)]]
  anel <- interaction(as.data.frame(xy[, lv, drop = FALSE]), drop = TRUE, lex.order = TRUE)
  q <- cbind(round((xy[, "X"] - mo$x0) * mo$k * mo$s), round((mo$y1 - xy[, "Y"]) * mo$s))
  por_fe <- split(seq_len(nrow(xy)), fe)
  out <- vapply(por_fe, function(ix) {
    an <- lapply(split(ix, droplevels(anel[ix])), function(j) {
      p <- q[j, , drop = FALSE]
      p <- p[c(TRUE, rowSums(abs(diff(p))) > 0), , drop = FALSE]
      if (nrow(p) > 1 && all(p[1, ] == p[nrow(p), ])) p <- p[-nrow(p), , drop = FALSE]
      if (nrow(p) < 3) return(NULL)
      d <- diff(p)
      paste0("M", p[1, 1], " ", p[1, 2], "l",
             gsub(" -", "-", paste(t(d), collapse = " "), fixed = TRUE), "z")
    })
    d <- paste(unlist(an), collapse = "")
    # menor que um vértice da moldura: vira um quadradinho de 1 unidade no
    # primeiro ponto, para o município continuar clicável e marcável
    if (d == "") d <- paste0("M", q[ix[1], 1], " ", q[ix[1], 2], "h1v1h-1z")
    d
  }, "")
  list(id = ids[as.integer(names(por_fe))], d = unname(out))
}
escreve <- function(x, f) {
  writeLines(toJSON(x, auto_unbox = TRUE, digits = NA), file.path(SAIDA, "malha", f), useBytes = TRUE)
  file.size(file.path(SAIDA, "malha", f))
}

gm <- st_read(file.path(RAIZ, "dados", "muni_2022_k03_d3.geojson"), quiet = TRUE) |>
  arrange(code_muni)
stopifnot(setequal(gm$code_muni, m$code_muni))
gu <- st_read(file.path(RAIZ, "dados", "uf_2020_k03_d3.geojson"), quiet = TRUE)

mo  <- moldura(gm, 1200)
br  <- codifica(gm, gm$code_muni, mo)
bru <- codifica(gu, gu$abbrev_state, mo)
tam <- escreve(list(w = mo$W, h = mo$H, id = I(br$id), d = I(br$d),
                    fronteira = paste(bru$d, collapse = "")), "br.json")
cat("br.json:", round(tam / 1024), "KB; municípios reduzidos a um quadradinho:",
    sum(grepl("^M[0-9]+ [0-9]+h1v1h-1z$", br$d)), "\n")

gm$uf <- m$uf[match(gm$code_muni, m$code_muni)]
tam_uf <- sapply(sort(unique(gm$uf)), function(u) {
  s <- gm[gm$uf == u, ]
  mu <- moldura(s, 1600, grau = 0.002)
  e <- codifica(s, s$code_muni, mu)
  escreve(list(w = mu$W, h = mu$H, id = I(e$id), d = I(e$d)), paste0("uf-", u, ".json"))
})
cat("UFs:", round(sum(tam_uf) / 1024), "KB no total; maior:",
    names(which.max(tam_uf)), round(max(tam_uf) / 1024), "KB\n")

# -- fontes do site (as mesmas do @fontsource que o Astro empacota) ---------------
fs <- file.path(SITE, "node_modules", "@fontsource")
ok <- file.copy(c(file.path(fs, "ibm-plex-sans", "files", "ibm-plex-sans-latin-400-normal.woff2"),
                  file.path(fs, "ibm-plex-sans", "files", "ibm-plex-sans-latin-600-normal.woff2"),
                  file.path(fs, "ibm-plex-mono", "files", "ibm-plex-mono-latin-400-normal.woff2")),
                file.path(SAIDA, "fontes"), overwrite = TRUE)
stopifnot(all(ok))

# -- HTML --------------------------------------------------------------------------
D <- list(
  meta = list(gerado = format(Sys.Date()),
              snapshot = readLines(file.path(RAIZ, "dados", "SNAPSHOT"), warn = FALSE)),
  ufs = list(sigla = ufs$uf, nome = ufs$name_state, regiao = ufs$name_region),
  mun = mun
)
modelo <- readLines(file.path(RAIZ, "painel", "modelo.html"), encoding = "UTF-8", warn = FALSE)
i <- grep("/*__DADOS__*/", modelo, fixed = TRUE)
stopifnot(length(i) == 1)
# "</" no JSON fecharia o <script>; colado por partes, sem sub(), para nenhuma
# barra invertida do JSON ser lida como escape
json <- gsub("</", "<\\/", toJSON(D, auto_unbox = FALSE, digits = NA), fixed = TRUE)
partes <- strsplit(modelo[i], "/*__DADOS__*/", fixed = TRUE)[[1]]
modelo[i] <- paste0(partes[1], json, partes[2])
con <- file(file.path(SAIDA, "index.html"), open = "w", encoding = "UTF-8")
writeLines(modelo, con, useBytes = FALSE); close(con)

arqs <- list.files(SAIDA, recursive = TRUE, full.names = TRUE)
cat("painel em", SAIDA, ":", length(arqs), "arquivos,",
    round(sum(file.size(arqs)) / 1024), "KB brutos; index.html",
    round(file.size(file.path(SAIDA, "index.html")) / 1024), "KB\n")

# -- conferência dos números que o artigo cita -------------------------------------
tot <- sum(m$dom_total); rt <- sum(m$rur_total); rq <- sum(m$rur_queimado); qu <- sum(m$dom_queimado)
cat(sprintf("Brasil queima %.2f%% | campo %.2f%% | cidade %.2f%% | MA %.2f%%\n",
            100 * qu / tot, 100 * rq / rt, 100 * (qu - rq) / (tot - rt),
            with(filter(m, uf == "MA"), 100 * sum(dom_queimado) / sum(dom_total))))
