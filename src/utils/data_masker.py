"""
Módulo para mascaramento de dados sensíveis conforme LGPD
"""
import re
from typing import Dict, Any, Optional


class DataMasker:
    """Classe para mascaramento de dados pessoais sensíveis (PII)"""
    
    @staticmethod
    def mask_cpf(cpf: str) -> str:
        """
        Mascara CPF: 123.456.789-00 → ***.456.***-00
        """
        if not cpf or len(cpf) < 11:
            return cpf
        
        # Remove formatação
        cpf_clean = re.sub(r'[^\d]', '', cpf)
        
        if len(cpf_clean) != 11:
            return cpf
        
        # Mascara: mantém apenas os 3 últimos dígitos antes do traço e os 2 últimos
        masked = f"***.{cpf_clean[3:6]}*.{cpf_clean[7:9]}-{cpf_clean[-2:]}"
        return masked
    
    @staticmethod
    def mask_email(email: str) -> str:
        """
        Mascara email: usuario@email.com → u*****@e***.com
        """
        if not email or '@' not in email:
            return email
        
        local, domain = email.split('@', 1)
        
        # Mascara parte local
        if len(local) > 1:
            masked_local = local[0] + '*' * (len(local) - 1)
        else:
            masked_local = '*'
        
        # Mascara domínio
        if '.' in domain:
            domain_parts = domain.split('.')
            masked_domain = domain_parts[0][0] + '***' + '.' + '.'.join(domain_parts[1:])
        else:
            masked_domain = domain[0] + '***'
        
        return f"{masked_local}@{masked_domain}"
    
    @staticmethod
    def mask_phone(phone: str) -> str:
        """
        Mascara telefone: (11) 98765-4321 → (11) 9****-4321
        """
        if not phone:
            return phone
        
        # Remove formatação
        phone_clean = re.sub(r'[^\d]', '', phone)
        
        if len(phone_clean) < 10:
            return phone
        
        # Formato brasileiro: (XX) 9XXXX-XXXX
        if len(phone_clean) == 11:
            masked = f"({phone_clean[:2]}) {phone_clean[2]}****-{phone_clean[-4:]}"
        elif len(phone_clean) == 10:
            masked = f"({phone_clean[:2]}) ****-{phone_clean[-4:]}"
        else:
            masked = '*' * (len(phone_clean) - 4) + phone_clean[-4:]
        
        return masked
    
    @staticmethod
    def mask_name(name: str) -> str:
        """
        Mascara nome: João Silva → J*** S****
        """
        if not name:
            return name
        
        parts = name.split()
        masked_parts = []
        
        for part in parts:
            if len(part) > 1:
                masked_parts.append(part[0] + '*' * (len(part) - 1))
            else:
                masked_parts.append('*')
        
        return ' '.join(masked_parts)
    
    @staticmethod
    def mask_card_number(card_number: str) -> str:
        """
        Mascara número de cartão: 1234 5678 9012 3456 → **** **** **** 3456
        """
        if not card_number:
            return card_number
        
        # Remove espaços e formatação
        card_clean = re.sub(r'[^\d]', '', card_number)
        
        if len(card_clean) < 4:
            return card_number
        
        # Mostra apenas os últimos 4 dígitos
        masked = '*' * (len(card_clean) - 4) + card_clean[-4:]
        
        # Adiciona espaços a cada 4 dígitos se o original tinha
        if ' ' in card_number:
            masked = ' '.join([masked[i:i+4] for i in range(0, len(masked), 4)])
        
        return masked
    
    def mask_pii(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Mascara todos os campos PII em um dicionário
        """
        masked_data = data.copy()
        
        # Campos conhecidos para mascarar
        pii_fields = {
            'cpf': self.mask_cpf,
            'email': self.mask_email,
            'phone': self.mask_phone,
            'telefone': self.mask_phone,
            'name': self.mask_name,
            'nome': self.mask_name,
            'card_number': self.mask_card_number,
            'numero_cartao': self.mask_card_number,
        }
        
        for field, mask_func in pii_fields.items():
            if field in masked_data and masked_data[field]:
                masked_data[field] = mask_func(str(masked_data[field]))
        
        return masked_data
    
    @staticmethod
    def anonymize_id(identifier: str, salt: Optional[str] = None) -> str:
        """
        Anonimiza um identificador usando hash
        """
        import hashlib
        
        if not identifier:
            return identifier
        
        if salt:
            identifier = identifier + salt
        
        return hashlib.sha256(identifier.encode()).hexdigest()[:16]


if __name__ == "__main__":
    # Testes
    masker = DataMasker()
    
    print("Teste de Mascaramento:")
    print(f"CPF: {masker.mask_cpf('123.456.789-00')}")
    print(f"Email: {masker.mask_email('usuario@email.com')}")
    print(f"Telefone: {masker.mask_phone('(11) 98765-4321')}")
    print(f"Nome: {masker.mask_name('João Silva')}")
    print(f"Cartão: {masker.mask_card_number('1234 5678 9012 3456')}")
    
    data = {
        'cpf': '123.456.789-00',
        'email': 'usuario@email.com',
        'phone': '(11) 98765-4321',
        'name': 'João Silva',
        'amount': 1000.00
    }
    
    print("\nDados mascarados:")
    print(masker.mask_pii(data))

