# 02_malha.R -----------------------------------------------------------------
# Malha municipal e estadual de 2022 (IBGE) lida com o geobr (Ipea) e
# simplificada para caber num artigo e num painel de navegador.
#
# Herdado de explora-pacotes-br/R/17_mapa.R e 18_geojson.R. A simplificacao
# (rmapshaper, 3% dos vertices, topologia preservada) e feita UMA vez aqui; o
# artigo e o painel leem o GeoJSON pronto e nao chamam o geobr.
#
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" R/02_malha.R

suppressMessages({library(geobr); library(sf); library(dplyr); library(arrow)})
# Rodar da raiz do projeto (a pasta com o CONTEXTO-PROJETO.md).
RAIZ <- normalizePath(".", winslash = "/")
stopifnot(file.exists(file.path(RAIZ, "CONTEXTO-PROJETO.md")))
saida <- function(f) file.path(RAIZ, "dados", f)

mu <- read_municipality(year = 2022, simplified = TRUE, showProgress = FALSE)
uf <- read_state(year = 2020, simplified = TRUE, showProgress = FALSE)
cat("municipios na malha:", nrow(mu), " UFs:", nrow(uf), "\n")

m <- read_parquet(saida("censo2022_muni_lixo.parquet"))
cat("municipios do Censo sem poligono:", sum(!m$code_muni %in% mu$code_muni),
    " poligonos sem Censo:", sum(!mu$code_muni %in% m$code_muni), "\n")

simplifica <- function(g, keep) rmapshaper::ms_simplify(g, keep = keep, keep_shapes = TRUE)

# So o codigo vai no GeoJSON: os indicadores vem do parquet e entram por
# junção. Assim o mesmo arquivo serve a qualquer variavel, e o painel nao
# carrega numero duplicado.
gm <- simplifica(mu |> mutate(code_muni = as.integer(code_muni)) |> select(code_muni), 0.03)
gu <- simplifica(uf |> mutate(code_state = as.integer(code_state)) |> select(code_state, abbrev_state), 0.03)

writeLines(geojsonsf::sf_geojson(gm, digits = 3), saida("muni_2022_k03_d3.geojson"))
writeLines(geojsonsf::sf_geojson(gu, digits = 3), saida("uf_2020_k03_d3.geojson"))
for (f in c("muni_2022_k03_d3.geojson", "uf_2020_k03_d3.geojson"))
  cat(f, "MB:", round(file.size(saida(f)) / 1e6, 2), "\n")
