# 03_exportar_site.R ---------------------------------------------------------
# Leva ao repo do site o que o artigo le: os retratos, a malha simplificada e a
# copia do tema. O site nao chama censobr nem geobr: le estes arquivos.
#
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" R/03_exportar_site.R

# Rodar da raiz do projeto (a pasta com o CONTEXTO-PROJETO.md).
RAIZ <- normalizePath(".", winslash = "/")
stopifnot(file.exists(file.path(RAIZ, "CONTEXTO-PROJETO.md")))
# Repo do site ao lado deste (../theoalbuquerque-site), ou a variavel SITE_QUARTO.
SITE <- Sys.getenv("SITE_QUARTO", file.path(dirname(RAIZ), "theoalbuquerque-site", "quarto"))
stopifnot(dir.exists(SITE))

destino <- file.path(SITE, "_dados", "lixo")
dir.create(destino, showWarnings = FALSE, recursive = TRUE)

arqs <- c("censo2022_muni_lixo.parquet", "censo2022_muni_situacao_cor.parquet",
          "censo2022_uf_responsaveis_cor.parquet",
          "muni_2022_k03_d3.geojson", "uf_2020_k03_d3.geojson", "SNAPSHOT")
ok <- file.copy(file.path(RAIZ, "dados", arqs), destino, overwrite = TRUE)
stopifnot(all(ok))

ok <- file.copy(file.path(RAIZ, "R", "tema.R"), file.path(SITE, "_temas", "lixo.R"),
                overwrite = TRUE)
stopifnot(ok)
cat("copiados", length(arqs), "arquivos para", destino, "e o tema para _temas/lixo.R\n")
