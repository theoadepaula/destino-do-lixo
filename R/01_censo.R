# 01_censo.R -----------------------------------------------------------------
# Censo 2022, agregados por setor censitario (IBGE), lidos com o censobr (Ipea),
# somados por municipio. Gera os retratos que o artigo e o painel leem.
#
# Herdado de explora-pacotes-br/R/15_censo_muni.R, ampliado com: cor ou raca do
# responsavel (V00421-V00450), moradores por destino (V00612-V00617), situacao
# urbana/rural do setor e as duas camadas de supressao do IBGE (ver abaixo).
#
# Rodar da raiz do projeto:
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" R/01_censo.R
#
# SUPRESSAO -- medida em 2026-11-01, corrige a exploracao:
#   * setor inteiro: 8.684 setores sem nenhuma variavel de domicilio (V00001 NA).
#     Sao setores minusculos: somam 20.228 domicilios ocupados no Basico (V0007).
#   * celula: dentro dos setores publicados, toda contagem de 1 ou 2 vira NA (o
#     menor valor positivo publicado e 3). Isso tira 294.773 domicilios da
#     quebra por destino do lixo. NAO e setor suprimido.
#   A exploracao contava "22.606 setores suprimidos" olhando so V00397 (coleta):
#   eram os 8.684 setores inteiros mais 13.922 setores em que a coleta tinha 1 ou
#   2 domicilios. O numero nao serve como "setores sem dado".

suppressMessages({library(censobr); library(dplyr); library(tidyr); library(arrow)})
# Rodar da raiz do projeto (a pasta com o CONTEXTO-PROJETO.md).
RAIZ <- normalizePath(".", winslash = "/")
stopifnot(file.exists(file.path(RAIZ, "CONTEXTO-PROJETO.md")))
set_censobr_cache_dir(file.path(RAIZ, "dados", "cache_censobr"))

v <- function(prefixo, n) sprintf("%s_V%05d", prefixo, n)
DEST <- c("coletado", "cacamba", "queimado", "enterrado", "baldio", "outro")
COR  <- c("branca", "preta", "amarela", "parda", "indigena")

d <- read_tracts(2022, "Domicilio", showProgress = FALSE, verbose = FALSE)
x <- d |>
  select(code_region, name_region, code_state, name_state, code_muni, name_muni,
         code_tract, situacao,
         all_of(c(v("domicilio01", 1), v("domicilio02", c(397:402, 309:316, 421:450)),
                  v("domicilio03", 612:617)))) |>
  collect()
names(x) <- sub("^domicilio0[123]_", "", names(x))
x <- x |> mutate(across(starts_with("V0"), as.numeric))

b <- read_tracts(2022, "Basico", showProgress = FALSE, verbose = FALSE) |>
  select(code_tract, V0007) |> collect() |> mutate(V0007 = as.numeric(V0007))
x <- left_join(x, b, by = "code_tract")

x <- x |>
  rename(dppo = V00001,
         all_of(setNames(sprintf("V%05d", 397:402), paste0("dom_", DEST))),
         all_of(setNames(sprintf("V%05d", 612:617), paste0("mor_", DEST))),
         all_of(setNames(sprintf("V%05d", 421:450),
                         paste0("cor_", rep(DEST, each = 5), "_", rep(COR, 6))))) |>
  mutate(suprimido = is.na(dppo),
         rural = situacao == "Rural",
         lixo_setor = rowSums(pick(starts_with("dom_")), na.rm = TRUE),
         rur_total    = if_else(rural, lixo_setor, 0),
         rur_queimado = if_else(rural, coalesce(dom_queimado, 0), 0))

cat("setores:", nrow(x), " suprimidos inteiros:", sum(x$suprimido),
    " DPO no Basico desses setores:", sum(x$V0007[x$suprimido]), "\n")
cat("menor contagem positiva publicada (lixo):",
    min(unlist(x[paste0("dom_", DEST)])[unlist(x[paste0("dom_", DEST)]) > 0], na.rm = TRUE), "\n")

# --- municipio ---------------------------------------------------------------
m <- x |>
  group_by(code_region, name_region, code_state, name_state, code_muni, name_muni) |>
  summarise(
    across(c(dppo, starts_with("dom_"), starts_with("mor_"), starts_with("rur_"),
             all_of(sprintf("V%05d", 309:316))), ~ sum(.x, na.rm = TRUE)),
    n_setores = n(), n_suprimidos = sum(suprimido),
    dpo_basico_suprimidos = sum(V0007[suprimido], na.rm = TRUE),
    .groups = "drop") |>
  mutate(
    dom_total = dom_coletado + dom_cacamba + dom_queimado + dom_enterrado + dom_baldio + dom_outro,
    lacuna_celula = dppo - dom_total,
    esg_total = V00309 + V00310 + V00311 + V00312 + V00313 + V00314 + V00315 + V00316,
    esg_rede  = V00309 + V00310,
    p_coleta  = (dom_coletado + dom_cacamba) / dom_total,
    p_queima  = dom_queimado / dom_total,
    p_rede    = esg_rede / esg_total,
    p_rural   = rur_total / dom_total
  ) |>
  select(-starts_with("V00"))

# Lixo e esgoto sao do mesmo universo (DPPO), mas a supressao de celula corta
# cada tabela por conta propria: os totais nao batem por municipio. Por isso
# p_rede usa o proprio denominador (esg_total), nunca dom_total.
stopifnot(all(m$lacuna_celula >= 0), all(m$rur_queimado <= m$rur_total))

uf_sigla <- c(`11`="RO",`12`="AC",`13`="AM",`14`="RR",`15`="PA",`16`="AP",`17`="TO",
  `21`="MA",`22`="PI",`23`="CE",`24`="RN",`25`="PB",`26`="PE",`27`="AL",`28`="SE",`29`="BA",
  `31`="MG",`32`="ES",`33`="RJ",`35`="SP",`41`="PR",`42`="SC",`43`="RS",
  `50`="MS",`51`="MT",`52`="GO",`53`="DF")
m <- m |> mutate(code_state = as.integer(code_state), code_muni = as.integer(code_muni),
                 code_region = as.integer(code_region),
                 uf = unname(uf_sigla[as.character(code_state)]))
stopifnot(!anyNA(m$uf), nrow(m) == 5570)
write_parquet(m, file.path(RAIZ, "dados", "censo2022_muni_lixo.parquet"))

# --- municipio x situacao x cor ou raca do responsavel -------------------------
# So total e queimado: e o que o recorte por cor usa. Municipio x situacao e o
# nivel em que a padronizacao do artigo compara cada grupo com os domicilios de
# responsavel branco do mesmo lugar.
cr <- x |>
  filter(!suprimido) |>
  mutate(code_muni = as.integer(code_muni)) |>
  group_by(code_muni, situacao) |>
  summarise(across(starts_with("cor_"), ~ sum(.x, na.rm = TRUE)), .groups = "drop") |>
  pivot_longer(starts_with("cor_"), names_to = c("destino", "cor"),
               names_pattern = "cor_([a-z]+)_([a-z]+)", values_to = "domicilios") |>
  group_by(code_muni, situacao, cor) |>
  summarise(total = sum(domicilios), queimado = sum(domicilios[destino == "queimado"]),
            .groups = "drop") |>
  filter(total > 0)
write_parquet(cr, file.path(RAIZ, "dados", "censo2022_muni_situacao_cor.parquet"))

# --- responsaveis por cor ou raca (Pessoas), para medir a cobertura -----------
# A tabela destino x cor perde mais para a supressao de celula do que a tabela
# de destino: sao 30 celulas por setor em vez de 6. O total de responsaveis por
# cor (Pessoas, V01332-V01336) mostra quanto de cada grupo ficou de fora.
p <- read_tracts(2022, "Pessoas", showProgress = FALSE, verbose = FALSE)
resp <- p |> select(code_state, all_of(sprintf("raca_V%05d", 1332:1336))) |> collect()
names(resp) <- c("code_state", COR)
resp <- resp |> mutate(code_state = as.integer(code_state), across(all_of(COR), as.numeric)) |>
  group_by(code_state) |> summarise(across(all_of(COR), ~ sum(.x, na.rm = TRUE))) |>
  pivot_longer(all_of(COR), names_to = "cor", values_to = "responsaveis")
write_parquet(resp, file.path(RAIZ, "dados", "censo2022_uf_responsaveis_cor.parquet"))

# --- conferencias ---------------------------------------------------------------
br <- colSums(m[paste0("dom_", DEST)]); tot <- sum(br)
print(round(100 * br / tot, 2))
cat("DPPO (V00001):", sum(m$dppo), " com destino do lixo:", tot,
    " lacuna de celula:", sum(m$lacuna_celula), "\n")
cat("cor x destino:", sum(cr$total), "  responsaveis (Pessoas):", sum(resp$responsaveis), "\n")
cat("municipios:", nrow(m), " com >50% queima:", sum(m$p_queima > .5), "\n")
for (f in c("censo2022_muni_lixo", "censo2022_muni_situacao_cor", "censo2022_uf_responsaveis_cor"))
  cat(f, "KB:", round(file.size(file.path(RAIZ, "dados", paste0(f, ".parquet"))) / 1024), "\n")
