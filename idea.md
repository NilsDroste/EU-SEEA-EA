# Methodological Framework: Transboundary Shadow Pricing of Ecosystem Services in the European Union

## 1. Overall Objective
The primary objective of this framework is to compute **systemic shadow prices for transboundary Ecosystem Services (ES)** across multiple European Union Member States. 

Because ecosystems do not conform to political borders, and the EU Single Market allows for heavy separation between where goods are consumed and where environmental resources are degraded, this framework captures the true economic cost of nature's inputs. It shifts environmental valuation away from subjective consumer preferences (such as willingness-to-pay surveys) toward a **systemic valuation model**. The shadow price is determined endogenously by calculating how much macroeconomic flexibility or industrial consumption must be traded off to preserve the baseline stock of underlying European ecosystem assets.

---

## 2. Integrated Methodological Approach
The methodology integrates the environmental structural accounting rules of the **United Nations SEEA EA** with the macroeconomic behavioral feedback loops of an **environmentally extended Multi-Regional Input-Output (EE-MRIO) model**, driven by an **IS-LM/SFC concurrent equilibrium engine**.

### Step 1: The Multi-Regional Supply Chain Engine (The IS Transformation)
Traditional macroeconomics relies on a single generic variable for output ($Y$). This model disaggregates production across multiple EU nations and industries by utilizing the Leontief trade balance equation:

$$\mathbf{X} = (\mathbf{I} - \mathbf{A})^{-1}\mathbf{F}(r)$$

*   $\mathbf{X}$ is a multi-country vector of gross outputs across all EU sectors.
*   $(\mathbf{I} - \mathbf{A})^{-1}$ is the **Leontief Inverse** matrix tracking transboundary trade interdependencies.
*   $\mathbf{F}(r)$ is the vector of final demands across Member States, which is sensitive to the macroeconomic interest rate ($r$).

### Step 2: Incorporating Biophysical Ecosystem Rows
The economic matrix is extended by adding a biophysical coefficient row matrix ($\mathbf{R}$). This matrix maps the volume of physical ecosystem service flows consumed per unit of economic output by each industry in each European region.

### Step 3: Enforcing Stock-Flow Consistency & Portfolio Dynamics (The LM Feedbacks)
Ecosystem assets function as capital stocks ($\mathbf{K}_{eco}$) that pay a natural flow dividend in the form of ecosystem services. This framework applies **Stock-Flow Consistent (SFC)** principles: any extraction of an ecosystem flow must dynamically drain the respective physical asset stock account. 

The financial market (the "LM" loop) connects to this system through the multi-asset discount rate ($r$). If an EU state accumulates severe ecological asset degradation, the model restricts its long-term growth potential, increasing money demand and driving up the opportunity cost of capital.

### Step 4: Solving for the Dual Shadow Price Index
The systemic shadow prices ($\mathbf{P}_{shadow}$) are derived using the mathematical dual price framework of the Leontief system:

$$\mathbf{P} = \mathbf{A}^T\mathbf{P} + \mathbf{V} + \mathbf{R}^T\mathbf{P}_{shadow}$$

*   $\mathbf{P}$ is the vector of adjusted production costs across the EU.
*   $\mathbf{V}$ represents traditional primary inputs (wages, profits).
*   $\mathbf{P}_{shadow}$ is solved endogenously by setting it equal to the **Marginal Abatement Cost (MAC)** or the exact expenditure required to restore degraded ecosystem assets back to their sustainable baseline conditions (as recorded in the SEEA EA asset accounts). 

When a sector in Germany imports a high-impact agricultural product from Spain, the pass-through of $\mathbf{R}^T\mathbf{P}_{shadow}$ inflates the ultimate consumer price index of that supply chain. This macro-feedback loop naturally dampens ecologically destructive cross-border demand until the transboundary ecosystem stocks stabilize.

---

## 3. Empirical Data Sources

To operationalize this multi-country European system, biophysical accounts are integrated with official economic accounting matrices.

### A. Economic Data Engine: FIGARO
The structural backbone for cross-border trade loops is provided by the **Full International and Global Accounts for Research in Input-Output Analysis (FIGARO)** tables, co-developed by Eurostat and the Joint Research Centre (JRC).
*   **Application:** The model utilizes **FIGARO-REG** tables to segment the EU into **64 distinct industrial sectors across over 240 NUTS2 regions**, tracking intermediate supply dependencies between Member States.

### B. Ecosystem Asset (Extent) Accounts
*   **Objective:** To establish the baseline geographic location and spatial volume of specific environmental asset classifications (e.g., wetlands, mixed forests, marine habitats).
*   **Primary Source:** The **Copernicus Land Monitoring Service (CLMS)**, utilizing **CORINE Land Cover (CLC)** data alongside High-Resolution Layers (HRL) to map spatial boundaries down to a fine scale.

### C. Ecosystem Condition Accounts
*   **Objective:** To monitor the biophysical integrity or health status of the asset stocks. Changes in these metrics adjust the value of $\mathbf{P}_{shadow}$.
*   **Data Indicators:** 
    *   *Physical / Chemical:* Mapped using topsoil parameters from the **LUCAS (Land Use and Coverage Area Frame Survey)** database and water quality indexes from the **European Environment Agency (EEA)** hydrological monitoring network.
    *   *Biological / Structural:* Monitored via the **Common Bird and Butterfly Indices** curated by the **European Bird Census Council (EBCC)** alongside satellite-derived Leaf Area Indexes (LAI).

### D. Ecosystem Services (Flow) Accounts
*   **Objective:** To quantify the actual volume of biophysical benefits moving from environmental assets into industrial processes.
*   **Primary Source:** The European Commission's **INCA (Integrated Natural Capital Accounting)** platform. INCA translates raw environmental data into standardized, account-ready Supply and Use tables that align directly with the sectoral columns of the FIGARO economic matrices.
    *   *Provisioning Services:* Timber and biomass data are compiled via **European Forest Accounts (EFA)**.
    *   *Regulating Services:* Global climate regulation and carbon sequestration indices are integrated from the **Integrated Carbon Observation System (ICOS)** network, while air filtration metrics use data from the **EMEP (European Monitoring and Evaluation Programme)**.

---

## 4. Methodological Summary Table

| Operational Phase | Macro-Ecological Mechanism | Utilized Data Infrastructures |
| :--- | :--- | :--- |
| **Multi-Country Trade Optimization** | Computes transboundary trade flows and macro economic feedback loops ($\mathbf{X} = (\mathbf{I} - \mathbf{A})^{-1}\mathbf{F}(r)$). | [Eurostat/JRC FIGARO MRIO Database](https://ec.europa.eu/eurostat/web/esa-supply-use-input-output-tables/figaro) |
| **Asset Baseline Mapping** | Delineates spatial boundaries across the official EU Ecosystem Typology. | [Copernicus Land Monitoring Service (CLMS)](https://land.copernicus.eu/) |
| **Condition Monitoring** | Tracks biological, chemical, and physical asset metrics to trigger the penalty cost functions. | [LUCAS Topsoil Database](https://joint-research-centre.ec.europa.eu/projects-compendium/lucas_en) & [EEA Data Hub](https://www.eea.europa.eu/) |
| **Service Flow Quantifications** | Generates standardized ecosystem Supply and Use tables to match economic sector lines. | [EC Integrated Natural Capital Accounting (INCA)](https://ec.europa.eu/eurostat) & [ICOS Carbon Portal](https://www.icos-cp.eu/) |

---

## References

*   Cazcarro, I., Usubiaga-Liaño, A., Román, M. V., Piñero, P., Dietzenbacher, E., Rueda-Cantuche, J. M., & Arto, I. (2022). FIGARO-E3: a high-resolution extended multi-regional input-output database consistent with official statistics. *Journal of Economic Structures*, *11*(1), 1-25. [University of Groningen Repository](https://research.rug.nl/en/publications/figaro-e3-a-high-resolution-extended-multi-regional-input-output-/)
    `Cited by: 14`
*   Ehrlich, Ü. (2021). Contingent Valuation as a Tool for Environmental Economic Accounting: Case of Estonia. *SSRN Electronic Journal*. https://doi.org/10.2139/ssrn.3970916
    `Cited by: 2`
*   García-Rodríguez, A., Lazarou, N., Mandras, G., Salotti, S., Thissen, M., & Kalvelagen, E. (2025). Constructing interregional social accounting matrices for the EU: unfolding trade patterns and wages by education level. *Spatial Economic Analysis*, 1-24. https://doi.org/10.1080/17421772.2025.2461051
    `Cited by: 18`
*   Sauer, J., & Wossink, A. (2012). Marketed outputs and non-marketed ecosystem services: the evaluation of marginal costs. *European Review of Agricultural Economics*, *40*(4), 573-603. https://doi.org/10.1093/erae/jbs040
    `Cited by: 52`
*   United Nations, European Commission, Food and Agriculture Organization, Organisation for Economic Co-operation and Development, & World Bank Group. (2021). *System of Environmental-Economic Accounting—Ecosystem Accounting (SEEA EA)*. United Nations. [UN SEEA Knowledge Base](https://seea.un.org/)

### Additional Resource
*   To visualize foundational macroeconomic mechanics and feedback loops before implementing multi-sector disgradations, review [Macroeconomics: The IS-LM-PC Model Lecture](https://www.youtube.com/watch?v=7zvc1ECNHAo).