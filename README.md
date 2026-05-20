# Transboundary Shadow Pricing of Ecosystem Services in the EU

**Nils Droste** — University of Copenhagen

Replication repository for *"Systemic Shadow Prices for Transboundary Ecosystem Services: An Environmentally Extended Multi-Regional Input-Output Approach for the European Union"*.

---

## Overview

This project computes endogenous shadow prices for ecosystem services across EU Member States by integrating:

- **SEEA EA** national ecosystem asset and condition accounts
- **EE-MRIO** (environmentally extended multi-regional input-output) trade accounting via FIGARO-REG
- **IS-LM / Stock-Flow Consistent** macroeconomic feedback loops

The key result: a vector of systemic shadow prices **P_shadow** that captures the marginal abatement cost of restoring degraded ecosystem assets, passed through transboundary supply chains via the Leontief price dual.

## Repository Structure

```
.
├── data/
│   ├── raw/          # downloaded source data (not tracked in git — see scripts/)
│   └── processed/    # cleaned, model-ready tables
├── src/              # Julia package: EUSEEAShadow.jl
│   ├── mrio.jl           # Leontief engine & trade matrix construction
│   ├── ecosystem.jl      # biophysical extension (R matrix)
│   ├── sfc.jl            # stock-flow consistency & asset dynamics
│   └── shadow_price.jl   # dual price solver
├── scripts/
│   ├── 01_download_figaro.jl       # FIGARO MRIO tables (Eurostat/JRC)
│   ├── 02_download_copernicus.jl   # CORINE Land Cover / CLMS
│   ├── 03_process_inca.jl          # INCA ecosystem service flow tables
│   └── 04_run_model.jl             # end-to-end model run
├── paper/
│   ├── paper.qmd         # main manuscript (Quarto)
│   ├── appendix.qmd      # mathematical appendix
│   ├── references.bib    # bibliography
│   └── _quarto.yml       # render settings
├── notebooks/
│   └── 01_data_exploration.qmd
├── test/
│   └── runtests.jl
└── Project.toml
```

## Reproducing the Analysis

### Prerequisites

- [Julia ≥ 1.10](https://julialang.org/downloads/)
- [Quarto ≥ 1.5](https://quarto.org/docs/get-started/)

### Setup

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/eu-seea-shadow-pricing.git
cd eu-seea-shadow-pricing

# Instantiate Julia environment
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

### Data Acquisition

Run the numbered scripts in `scripts/` sequentially. Each script documents its data source and any required API keys or manual download steps.

```bash
julia --project=. scripts/01_download_figaro.jl
julia --project=. scripts/02_download_copernicus.jl
julia --project=. scripts/03_process_inca.jl
```

### Run the Model

```bash
julia --project=. scripts/04_run_model.jl
```

### Render the Paper

```bash
cd paper && quarto render paper.qmd
```

## Data Sources

| Dataset | Provider | Access |
|---|---|---|
| FIGARO-REG MRIO tables | Eurostat / JRC | [ec.europa.eu/eurostat](https://ec.europa.eu/eurostat/web/esa-supply-use-input-output-tables/figaro) |
| CORINE Land Cover (CLC) | Copernicus CLMS | [land.copernicus.eu](https://land.copernicus.eu/) |
| LUCAS Topsoil | JRC | [Joint Research Centre](https://joint-research-centre.ec.europa.eu/projects-compendium/lucas_en) |
| EEA Water Quality | European Environment Agency | [eea.europa.eu](https://www.eea.europa.eu/) |
| INCA ecosystem accounts | Eurostat | [ec.europa.eu/eurostat](https://ec.europa.eu/eurostat) |
| ICOS carbon fluxes | ICOS RI | [icos-cp.eu](https://www.icos-cp.eu/) |

## License

Code: MIT. Paper text and figures: CC BY 4.0.
