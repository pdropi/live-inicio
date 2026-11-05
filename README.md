# 🎬 Live Inicio (yt-dlp + mpv HLS Fast-Seek)

Permite assistir vídeos do YouTube de forma mais leve que no navegador, contornando limitações nativas do `mpv`.

[Português](#português) | [English](#english)

---

## 🇧🇷 Português

O **live-inicio** é um script em Bash para Linux projetado para abrir transmissões ao vivo (ou vídeos encerrados) no `mpv` a partir de um timestamp específico de forma **quase instantânea**, sem a necessidade de baixar todo o conteúdo anterior.

Esta solução é **muito mais leve do que assistir ao YouTube pelo navegador**, sendo ideal para computadores antigos, minipcs ou dispositivos de baixo custo (como o Raspberry Pi).

### ❓ Os Problemas e as Limitações que o script resolve

- **Limitação do mpv:** O parâmetro `--start=` do `mpv` não funciona nativamente em transmissões ao vivo (`is_live`), pois o player tenta reproduzir a partir do ponto atual do evento em tempo real.
- **Comportamento padrão das ferramentas:** Em transmissões ao vivo, o `yt-dlp` só permite baixar a partir do momento exato em tempo real ou a partir do início absoluto da live. Em transmissões longas (ex: 12 horas de live), ferramentas como o `yt-dlp` com a opção `--live-from-start` baixam sequencialmente todos os fragmentos desde o segundo zero. Se você tentar assistir a partir da 10ª hora, o sistema precisa baixar e descartar milhares de arquivos, gerando alto consumo de banda, lentidão e gargalo de I/O em discos rígidos ou cartões SD.

### 💡 A Solução

O script contorna esse gargalo calculando matematicamente o número de sequência (`sq`) do fragmento HLS/DASH correspondente ao timestamp desejado através dos cabeçalhos da transmissão (`x-head-seqnum` e `x-head-time-millis`). Ele faz o download paralelo direto via `curl` a partir do fragmento exato e injeta o fluxo no `mpv` através de FIFOs (`named pipes`).

---

### 📋 Requisitos e Instalação de Dependências

Certifique-se de ter as seguintes ferramentas instaladas e disponíveis no seu `$PATH`:

- **Bash**
- **yt-dlp**
- **Deno** (Engine JS simples e leve para resolver desafios do YouTube no `yt-dlp`)
- **mpv**
- **curl**
- **awk**, **grep**, **sed**, **tr** (utilitários padrões POSIX)

#### 📦 Instalação simples do Deno:
A instalação do Deno é simples e leva apenas alguns segundos:
```bash
curl -fsSL https://deno.land/install.sh | sh
```

#### 📦 Instalação simples do yt-dlp:
```bash
pipx install yt-dlp
```

#### 📦 Instalação simples do mpv:
- **Debian / Ubuntu / Raspberry Pi OS:**
  ```bash
  sudo apt update && sudo apt install mpv
  ```
- **Fedora:**
  ```bash
  sudo dnf install mpv
  ```
- **Arch Linux:**
  ```bash
  sudo pacman -S mpv
  ```

*Garanta que as variáveis de ambiente (PATH) das dependências estejam corretas e recarregue ou reinicie o shell (`bash`/`zsh`).*

---

### 🚀 Instalação e Uso

1. Clone o repositório ou baixe o script:
   ```bash
   git clone https://github.com/pdropi/live-inicio.git
   cd live-inicio
   ```

2. Dê permissão de execução ao script:
   ```bash
   chmod +x live-inicio.sh
   ```

3. Execute passando a URL da live e o tempo inicial em segundos (opcional):

   - **Assistir live do ponto atual (ou vídeo comum do início):**
     ```bash
     ./live-inicio.sh https://www.youtube.com/watch?v=EXEMPLO
     ```

   - **Iniciar a live a partir de um ponto exato (ex: 2 horas / 7200 segundos):**
     ```bash
     ./live-inicio.sh https://www.youtube.com/watch?v=EXEMPLO 7200
     ```

---

### ⚙️ Configurações Internas (Para CPUs Fracas)

No script, existe a variável `LOTE`:

```bash
LOTE=2 # Baixa 2 fragmentos de vídeo e 2 de áudio em paralelo (total: 4 conexões)
```

Em dispositivos com recursos limitados (como Raspberry Pi ou computadores antigos), o valor `2` garante excelente estabilidade. Em computadores mais potentes, você pode aumentar esse número para aceleração de buffer.

---

## 🇬🇧 English

**live-inicio** is a Linux Bash script designed to stream live broadcasts (or VODs) in `mpv` starting from a specific timestamp **almost instantly**, bypassing the need to download previous stream data.

This solution is **much lighter than streaming YouTube in a web browser**, making it perfect for low-spec systems, old computers, and single-board devices like the Raspberry Pi.

### ❓ Problems & Limitations Solved by the Script

- **mpv Limitation:** The standard `--start=` option in `mpv` does not work natively on live streams (`is_live`), as the player defaults to playing from the real-time live edge.
- **Standard Tool Behavior:** In live streams, `yt-dlp` only allows downloading either from the current real-time moment or from the absolute start of the stream. During long streams (e.g., a 12-hour stream), tools using `--live-from-start` download all fragments sequentially starting from second zero. Attempting to start watching at the 10th hour forces the system to download and discard thousands of segment files, causing heavy bandwidth usage, high disk I/O bottlenecks, and long wait times on HDDs or SD cards.

### 💡 The Solution

This script bypasses sequential downloads by fetching HTTP headers (`x-head-seqnum` and `x-head-time-millis`) to mathematically calculate the target fragment sequence number (`sq`). It then requests stream chunks in parallel directly via `curl` starting from the target index and pipes the stream live into `mpv` using FIFOs (`named pipes`).

---

### 📋 Prerequisites & Installation

Ensure you have the following dependencies installed in your environment:

- **Bash**
- **yt-dlp**
- **Deno** (Lightweight JS runtime to handle YouTube challenge scripts for `yt-dlp`)
- **mpv**
- **curl**
- **awk**, **grep**, **sed**, **tr** (standard POSIX tools)

#### 📦 Simple Deno Installation:
Installing Deno is straightforward and takes less than a minute:
```bash
curl -fsSL https://deno.land/install.sh | sh
```

#### 📦 Simple yt-dlp Installation:
```bash
pipx install yt-dlp
```

#### 📦 Simple mpv Installation:
- **Debian / Ubuntu / Raspberry Pi OS:**
  ```bash
  sudo apt update && sudo apt install mpv
  ```
- **Fedora:**
  ```bash
  sudo dnf install mpv
  ```
- **Arch Linux:**
  ```bash
  sudo pacman -S mpv
  ```

*Make sure your executable PATH environment variables are set correctly and reload or restart your shell (`bash`/`zsh`).*

---

### 🚀 Installation & Usage

1. Clone the repository:
   ```bash
   git clone https://github.com/pdropi/live-inicio.git
   cd live-inicio
   ```

2. Make the script executable:
   ```bash
   chmod +x live-inicio.sh
   ```

3. Run the script with a live stream URL and target offset in seconds:

   - **Watch live stream from the current live point (or regular video from start):**
     ```bash
     ./live-inicio.sh https://www.youtube.com/watch?v=EXAMPLE
     ```

   - **Start live stream from a specific offset (e.g., 2 hours / 7200 seconds):**
     ```bash
     ./live-inicio.sh https://www.youtube.com/watch?v=EXAMPLE 7200
     ```

---

### ⚙️ Performance Tuning

The script contains a batch tuning variable:

```bash
LOTE=2 # Downloads 2 video and 2 audio fragments in parallel per cycle
```

For low-spec hardware (such as Raspberry Pi or older PCs), a value of `2` provides smooth playback without CPU spikes. On high-spec computers, you can increase this value for faster buffering.

---

### 📜 License

MIT License. Free for modification and redistribution.
