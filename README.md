# destino-do-lixo

Destino do lixo dos domicílios brasileiros por município, Censo 2022
(`censobr`) + malha do IBGE (`geobr`). O porquê está em `CONTEXTO-PROJETO.md`.

## Rodar

Sempre da raiz do projeto. R 4.5.2, pacotes: censobr 1.0.0, geobr 2.1.0, arrow, dplyr, tidyr, sf,
rmapshaper, geojsonsf, theoviz >= 0.3.1. No Windows, sempre por arquivo:

```
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" R/01_censo.R          # ~2 min; baixa ~300 MB na 1a vez
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" R/02_malha.R
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" R/03_exportar_site.R  # copia para o site
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" R/04_retrato_painel.R
```

Depois, no site: rodar `quarto/posts/lixo-queimado-censo-2022/_conferir_prosa.R`
(da pasta do post) e re-renderizar o post.
