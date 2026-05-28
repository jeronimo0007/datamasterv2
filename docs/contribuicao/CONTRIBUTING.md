# Guia de Contribuição

Obrigado por considerar contribuir com o projeto!

## Como Contribuir

1. Fork o repositório
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## Padrões de Código

### Python
- Use Black para formatação
- Siga PEP 8
- Adicione docstrings para funções e classes
- Escreva testes para novas funcionalidades

### Java
- Siga as convenções do Spring Boot
- Use Lombok quando apropriado
- Adicione Javadoc para classes públicas
- Escreva testes unitários e de integração

## Testes

Certifique-se de que todos os testes passam antes de submeter:

```bash
# Python
pytest

# Java
cd api-java
./mvnw test
```

## Documentação

Atualize a documentação conforme necessário para refletir suas mudanças.

