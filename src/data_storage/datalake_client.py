"""
Cliente para operações no Azure Data Lake Gen2
"""
from azure.storage.filedatalake import DataLakeServiceClient
from azure.identity import DefaultAzureCredential
from typing import Optional, List
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DataLakeClient:
    """Cliente para interagir com Azure Data Lake Gen2"""
    
    def __init__(self, storage_account: str, connection_string: Optional[str] = None):
        """
        Inicializa o cliente do Data Lake
        
        Args:
            storage_account: Nome da conta de armazenamento
            connection_string: String de conexão (opcional, usa Managed Identity se não fornecido)
        """
        self.storage_account = storage_account
        account_url = f"https://{storage_account}.dfs.core.windows.net"
        
        if connection_string:
            # Usa connection string
            from azure.storage.filedatalake import DataLakeServiceClient
            self.service_client = DataLakeServiceClient.from_connection_string(
                conn_str=connection_string,
                account_url=account_url
            )
        else:
            # Usa Managed Identity
            self.service_client = DataLakeServiceClient(
                account_url=account_url,
                credential=DefaultAzureCredential()
            )
    
    def create_file_system(self, file_system_name: str) -> None:
        """
        Cria um file system (container)
        
        Args:
            file_system_name: Nome do file system
        """
        try:
            file_system_client = self.service_client.get_file_system_client(
                file_system=file_system_name
            )
            file_system_client.create_file_system()
            logger.info(f"File system criado: {file_system_name}")
        except Exception as e:
            if "ContainerAlreadyExists" in str(e):
                logger.info(f"File system já existe: {file_system_name}")
            else:
                logger.error(f"Erro ao criar file system: {e}")
                raise
    
    def create_directory(self, file_system_name: str, directory_path: str) -> None:
        """
        Cria um diretório
        
        Args:
            file_system_name: Nome do file system
            directory_path: Caminho do diretório
        """
        try:
            directory_client = self.service_client.get_directory_client(
                file_system=file_system_name,
                directory=directory_path
            )
            directory_client.create_directory()
            logger.info(f"Diretório criado: {directory_path}")
        except Exception as e:
            if "PathAlreadyExists" in str(e):
                logger.info(f"Diretório já existe: {directory_path}")
            else:
                logger.error(f"Erro ao criar diretório: {e}")
                raise
    
    def upload_file(self, file_system_name: str, file_path: str, 
                   local_file_path: str) -> None:
        """
        Faz upload de um arquivo
        
        Args:
            file_system_name: Nome do file system
            file_path: Caminho do arquivo no Data Lake
            local_file_path: Caminho do arquivo local
        """
        try:
            file_client = self.service_client.get_file_client(
                file_system=file_system_name,
                file_path=file_path
            )
            
            with open(local_file_path, 'rb') as f:
                file_client.upload_data(data=f, overwrite=True)
            
            logger.info(f"Arquivo enviado: {file_path}")
        except Exception as e:
            logger.error(f"Erro ao fazer upload: {e}")
            raise
    
    def upload_data(self, file_system_name: str, file_path: str, data: bytes) -> None:
        """
        Faz upload de dados em memória
        
        Args:
            file_system_name: Nome do file system
            file_path: Caminho do arquivo no Data Lake
            data: Dados em bytes
        """
        try:
            file_client = self.service_client.get_file_client(
                file_system=file_system_name,
                file_path=file_path
            )
            file_client.upload_data(data=data, overwrite=True)
            logger.info(f"Dados enviados: {file_path}")
        except Exception as e:
            logger.error(f"Erro ao fazer upload: {e}")
            raise
    
    def list_files(self, file_system_name: str, directory_path: str = "") -> List[str]:
        """
        Lista arquivos em um diretório
        
        Args:
            file_system_name: Nome do file system
            directory_path: Caminho do diretório
        
        Returns:
            Lista de caminhos de arquivos
        """
        try:
            paths = self.service_client.get_paths(
                path=directory_path,
                recursive=False
            )
            return [path.name for path in paths if not path.is_directory]
        except Exception as e:
            logger.error(f"Erro ao listar arquivos: {e}")
            raise
    
    def create_directory_structure(self, file_system_name: str) -> None:
        """
        Cria a estrutura de diretórios padrão do projeto
        
        Args:
            file_system_name: Nome do file system
        """
        directories = [
            "raw/transactions",
            "raw/reference",
            "processed/transactions",
            "processed/features",
            "curated/transactions",
            "curated/analytics",
            "models",
            "reports"
        ]
        
        self.create_file_system(file_system_name)
        
        for directory in directories:
            self.create_directory(file_system_name, directory)
        
        logger.info("Estrutura de diretórios criada com sucesso")


if __name__ == "__main__":
    # Exemplo de uso
    client = DataLakeClient(storage_account="fraudstorage")
    client.create_directory_structure("fraud-data")

