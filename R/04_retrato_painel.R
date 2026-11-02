# 04_retrato_painel.R ----------------------------------------------------------
# Retrato enxuto para o painel (etapa futura, ver CONTEXTO-PROJETO.md §6):
# uma linha por municipio, so o que o painel mostra, com nomes curtos. Junta-se
# ao GeoJSON dados/muni_2022_k03_d3.geojson por code_muni.
#
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" R/04_retrato_painel.R

suppressMessages({library(dplyr); library(arrow)})
# Rodar da raiz do projeto (a pasta com o CONTEXTO-PROJETO.md).
RAIZ <- normalizePath(".", winslash = "/")
stopifnot(file.exists(file.path(RAIZ, "CONTEXTO-PROJETO.md")))
m <- read_parquet(file.path(RAIZ, "dados", "censo2022_muni_lixo.parquet"))

p <- m |>
  transmute(code_muni, municipio = name_muni, uf, regiao = name_region,
            domicilios = as.integer(dom_total),
            coletado = as.integer(dom_coletado), cacamba = as.integer(dom_cacamba),
            queimado = as.integer(dom_queimado), enterrado = as.integer(dom_enterrado),
            baldio = as.integer(dom_baldio), outro = as.integer(dom_outro),
            moradores_queima = as.integer(mor_queimado),
            p_coleta = round(p_coleta, 4), p_queima = round(p_queima, 4),
            p_rede_esgoto = round(p_rede, 4), p_rural = round(p_rural, 4),
            lacuna_sigilo = as.integer(lacuna_celula),
            # contagens do lado rural (situacao do setor); o urbano e o total
            # menos o rural. Esgoto com o proprio total, como p_rede_esgoto.
            rural_domicilios = as.integer(rur_total), rural_queimado = as.integer(rur_queimado),
            rural_coleta = as.integer(rur_coleta),
            esgoto_total = as.integer(esg_total), esgoto_rede = as.integer(esg_rede),
            rural_esgoto_total = as.integer(rur_esg_total),
            rural_esgoto_rede = as.integer(rur_esg_rede))

stopifnot(nrow(p) == 5570, !anyDuplicated(p$code_muni))
f <- file.path(RAIZ, "dados", "painel_muni_lixo.parquet")
write_parquet(p, f, compression = "zstd")
write.csv(p, file.path(RAIZ, "dados", "painel_muni_lixo.csv"), row.names = FALSE,
          fileEncoding = "UTF-8")
cat("painel:", nrow(p), "linhas,", round(file.size(f) / 1024), "KB parquet,",
    round(file.size(sub("parquet$", "csv", f)) / 1024), "KB csv\n")
