"""
Arquitetura Medallion (camadas) e padroes de processamento em tempo real.

MEDALHAO (Bronze / Silver / Gold)
---------------------------------
- **Bronze:** landing fiel a origem (schema flexivel, retencao maior, auditoria).
  Ex.: JSON/Parquet/Avro como chegou do core, API ou Event Hub.
- **Silver:** dados limpos, deduplicados, tipados; regras de negocio e DQ.
  Ex.: `clean_transactions`, joins de enriquecimento.
- **Gold:** agregados e datasets de consumo (BI, ML serving batch, feature sets).
  Ex.: tabela wide para treino XGBoost, KPIs por dia.

O mesmo layout de prefixos funciona em **ADLS Gen2** (Azure) ou **S3** (AWS),
por exemplo: `s3://bucket/fraud/bronze/transactions`.

Lambda vs Kappa
---------------
- **Lambda:** duas vias — **speed** (streaming, baixa latencia, aproximado ou
  ultimo estado) + **batch** (reprocessamento completo, correccao, historico).
  O **serving** combina ou o usuario le a camada adequada. Encaixa em antifraude:
  score online via fila/API + recomputo diario no lake (Silver/Gold).
- **Kappa:** uma unica via tratada como **log/stream**; reprocessamento = replay.
  Menos componentes, mais pressao no motor de stream e no armazenamento de log.

Outras referencias
------------------
- **Data Mesh:** dominio e ownership por produto de dados (nao e um pipeline unico).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

Layer = Literal["bronze", "silver", "gold"]


LAMBDA_KAPPA_NOTES: str = __doc__ or ""


@dataclass(frozen=True)
class MedallionLayout:
    """
    Prefixos padrao no lake para alinhar codigo, Terraform e documentacao.

    base_uri exemplos:
    - Azure: abfss://container@storage.dfs.core.windows.net/fraud
    - AWS:   s3a://meu-bucket/fraud
    - Local demo: file:///.../data/lake  (opcional para testes)
    """

    base_uri: str

    def path(self, layer: Layer, entity: str = "transactions") -> str:
        key = str(layer).lower()
        return f"{self.base_uri.rstrip('/')}/{key}/{entity.strip('/')}"

    def bronze(self, entity: str = "transactions") -> str:
        return self.path("bronze", entity)

    def silver(self, entity: str = "transactions") -> str:
        return self.path("silver", entity)

    def gold(self, entity: str = "transactions_ml") -> str:
        return self.path("gold", entity)


# Aliases historicos (notebook legado raw/processed/curated)
LAYER_ALIASES: dict[str, Layer] = {
    "raw": "bronze",
    "landing": "bronze",
    "processed": "silver",
    "curated": "gold",
}
