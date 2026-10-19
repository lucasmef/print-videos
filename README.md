# LookPrint

App nativo para macOS Apple Silicon. Extrai automaticamente imagens das composições completas em vídeos com roupas e acessórios sobrepostos, em vídeos de moda com sobreposições de peças. Não exige instalação de bibliotecas, conta, chave de API ou internet.

## Usar

No Finder, selecione um ou mais vídeos e escolha **botão direito → Extrair looks completos** (em alguns menus, dentro de Serviços). Também é possível abrir o LookPrint e arrastar arquivos ou escolher vídeos.

Cada execução cria uma pasta própria em Downloads. Os JPGs preservam a resolução e o quadro inteiro: roupas, acessórios, apresentadora e legendas. O vídeo original não é alterado. `extracao.json` registra os instantes e o tempo de processamento. HDR é convertido para SDR na exportação JPEG.

A mesma roupa com acessórios diferentes conta como outra composição. Adições progressivas de peças são agrupadas, e uma imagem estável próxima ao final de cada composição é escolhida. Quadros com dois looks permanecem em uma única imagem.

## Como funciona

- AVFoundation lê oito miniaturas por segundo, com busca exata e rotação correta.
- Vision localiza o rosto em três instantes para escolher entre área lateral e superior. A área também pode ser escolhida no app.
- Comparações temporais descartam regiões de movimento frequente. Mudanças persistentes sugerem novos estados da composição.
- A seleção favorece imagens estáveis com mais detalhes, elimina duplicatas e estados aos quais ainda faltam peças. Trocas de acessórios são preservadas.
- Só as imagens selecionadas são exportadas na resolução original.

O detector usa regras visuais, não compreensão semântica universal de moda. Foi calibrado e verificado nos seis exemplos fornecidos. Vídeos com outro enquadramento, peças em movimento contínuo, câmera móvel, transições longas ou sem sobreposições podem exigir revisão. Não remove fundo, pessoa ou texto e não reconstrói partes ocultas. Limite desta versão: 2 minutos por vídeo; arquivos mais longos são rejeitados antes da análise.

## Desenvolvimento

Execute `./build.sh` com as ferramentas de linha de comando da Apple instaladas. O app é gerado em `build/LookPrint.app`, com assinatura local. A assinatura é adequada para este Mac; distribuição pública exige assinatura e notarização próprias.

O motor está em `Sources/Engine.swift`; a janela, fila de vídeos e serviço do Finder estão em `Sources/App.swift`. Os nomes e instantes dos vídeos de teste não entram na lógica do motor.

Para a ferramenta de validação:

```sh
swiftc -module-cache-path build/module-cache -O Sources/Engine.swift tools/main.swift -o build/look-cli
build/look-cli PASTA-DE-SAIDA VIDEO1 VIDEO2
```

`tools/verify_reports.py` confere os seis relatórios de regressão (contagens, instantes e JPGs em resolução original), com Pillow. Essa dependência é apenas de desenvolvimento.

O serviço segue a [integração nativa de Serviços do macOS](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/properties.html). A busca exata de frames usa a [tolerância zero do AVAssetImageGenerator](https://developer.apple.com/documentation/avfoundation/avassetimagegenerator/requestedtimetolerancebefore).

## Validação histórica

No desenvolvimento original, a versão gerou 46 JPGs: 49 (10), 120 (5), 125 (10), 139 (4), 152 (7), 122-mexido (10). Todos os quadros foram conferidos visualmente, e as dimensões e os instantes foram validados. A execução dos seis vídeos no extrator levou de 6,7 a 13,1 segundos por arquivo. O teste real pelo Finder abriu o app e salvou sete imagens de 152.mov em Downloads. A primeira execução do app levou 93,9 s; a repetição levou 8,1 s. O tempo de primeira abertura pode ser maior.


## Requisitos

- macOS 14 ou superior em Mac com Apple Silicon.
- Xcode Command Line Tools para compilar (`xcode-select --install`).
- Python 3 e Pillow apenas para os scripts de revisão de imagens.

Depois de compilar, abra `build/LookPrint.app`. Para disponibilizar o serviço no Finder, copie o app para Aplicativos e confira a opção em Ajustes do Sistema → Teclado → Atalhos de Teclado → Serviços.

## Estrutura do projeto

| Caminho | Conteúdo |
| --- | --- |
| `Sources/App.swift` | Interface SwiftUI, fila e integração com o Finder |
| `Sources/Engine.swift` | Detecção de composições e exportação de quadros |
| `Info.plist` | Configuração do aplicativo e do serviço |
| `build.sh` | Compilação para Apple Silicon e assinatura local |
| `tools/` | Utilitários de inspeção, revisão e processamento em lote |

## Scripts de lote

Os scripts auxiliares usam caminhos relativos ao projeto. Defina `LOOKPRINT_VIDEO_DIR` para a pasta de vídeos e, se necessário, `LOOKPRINT_BATCH_DIR` para o diretório de trabalho (padrão: `analysis/batch`).

```sh
export LOOKPRINT_VIDEO_DIR="$HOME/Movies/LookPrint"
python3 tools/process_looks.py
python3 tools/sheets_looks.py
python3 tools/show_looks.py 1 36
```

Compile `build/look-cli` antes de processar o lote. Os scripts de revisão precisam de Pillow (`python3 -m pip install Pillow`). `tools/Inspect.swift` recebe a pasta de saída e a pasta dos vídeos como argumentos. Os utilitários dos seis exemplos dependem de arquivos de referência locais que não acompanham o repositório.

`tools/finalize_finder_looks.py` é um utilitário do fluxo local: depende de `tags-visuais.txt`, `itens.json` e do executável externo `build/apply-finder-tags`, cujo código não está neste projeto. Ele pode remover da pasta de saída as imagens marcadas como `excluir`; use apenas sobre resultados revisados.

## Privacidade

O aplicativo processa vídeos localmente, sem API externa. Os relatórios `extracao.json` registram o caminho completo do vídeo de origem, portanto devem ser revisados antes de compartilhar.

Vídeos, prints, relatórios, resultados de análise, builds e arquivos de credenciais ficam fora do Git. O repositório contém o código, o ícone, a configuração e esta documentação. O identificador `br.com.lucas.lookprint` é um identificador de aplicativo, não uma credencial.

A validação histórica acima descreve os exemplos do desenvolvimento original e não garante resultados iguais em outros vídeos.
