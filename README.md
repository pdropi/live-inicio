# live-inicio
Permite assistir vídeos do youtube de forma mais leve que no navegador, contornando limitações do mpv

# 🎬 Live Inicio (yt-dlp + mpv HLS Fast-Seek)

[Português](#português) | [English](#english)

## 🇧🇷 Português

O **live-inicio** é um script em Bash para Linux projetado para abrir transmissões ao vivo (ou vídeos encerrados) no `mpv` a partir de um timestamp específico de forma **quase instantânea**, sem a necessidade de baixar todo o conteúdo anterior.

Esta solução é **muito mais leve do que assistir ao YouTube pelo navegador**, sendo ideal para computadores antigos, minipc ou dispositivos de baixo custo (como o Raspberry Pi).

### ❓ O Problema e as Limitações

* **Limitação do mpv:** O parâmetro `--start=` do `mpv` não funciona nativamente em transmissões ao vivo (`is_live`), pois o player tenta reproduzir a partir do ponto atual do evento em tempo real.
* **Comportamento padrão das ferramentas:** Em transmissões ao vivo longas (ex: 12 horas de live), ferramentas como o `yt-dlp` com a opção `--live-from-start` baixam sequencialmente todos os fragmentos desde o segundo zero. Se você tentar assistir a partir da 10ª hora, o sistema precisa baixar e descartar milhares de arquivos, gerando alto consumo de banda, lentidão e gargalo de I/O em discos rígidos ou cartões SD.

### 💡 A Solução

O script contorna esse gargalo calculando matematicamente o número de sequência (`sq`) do fragmento HLS/DASH correspondente ao timestamp desejado através dos cabeçalhos da transmissão (`x-head-seqnum` e `x-head-time-millis`). Ele faz o download paralelo direto via `curl` a partir do fragmento exato e injeta o fluxo no `mpv` através de FIFOs (`named pipes`).

### 📋 Requisitos

Certifique-se de ter as seguintes ferramentas instaladas e disponíveis no seu `$PATH`:

* **Bash**
* **yt-dlp**
* **Deno** (Engine JS simples e leve para resolver desafios do YouTube no `yt-dlp`)
* **mpv**
* **curl**
* **awk**, **grep**, **sed**, **tr** (utilitários padrões POSIX)

#### 📦 Instalação simples do Deno:

A instalação do Deno é simples e leva apenas alguns segundos:

```bash
curl -fsSL https://deno.land/install.sh | sh
```

*Garanta que os PATH das dependências estejam corretas e recarregue ou reinicie o bash/zash/ash*

#### 📦 Instalação simples do yt-dpl:

```bash
pipx install yt-dlp
```

---

### 🚀 Instalação e Uso

1. Clone o repositório ou baixe o script:

   ```bash
   git clone https://github.com/pdropi/live-inicio.git
   cd live-inicio
   ```

2. Dê permissão de execução ao script:

   ```bash
   chmod +x live-inicio
   ```

3. Execute passando a URL da live e o tempo inicial em segundos (opcional):

   * **Assistir live do ponto atual (ou vídeo comum do início):**

     ```bash
     ./live-inicio https://www.youtube.com/watch?v=EXEMPLO
     ```

   * **Iniciar a live a partir de um ponto exato (ex: 2 horas / 7200 segundos):**

     ```bash
     ./live-inicio https://www.youtube.com/watch?v=EXEMPLO 7200
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

### ❓ The Problem & Known Limitations

* **mpv Limitation:** The standard `--start=` option in `mpv` does not work natively on live streams (`is_live`), as the player defaults to playing from the real-time live edge.
* **Standard Tool Behavior:** During long live streams (e.g., a 12-hour YouTube stream), tools using `--live-from-start` download all fragments sequentially from second zero. Attempting to start watching at the 10th hour forces the system to download and discard thousands of segment files, causing heavy bandwidth usage, high disk I/O, and long wait times.

### 💡 The Solution

This script bypasses sequential downloads by fetching HTTP headers (`x-head-seqnum` and `x-head-time-millis`) to mathematically calculate the target fragment sequence number (`sq`). It then requests stream chunks in parallel directly via `curl` starting from the target index and pipes the stream live into `mpv` using FIFOs (`named pipes`).

### 📋 Prerequisites

Ensure you have the following dependencies installed in your environment:

* **Bash**
* **yt-dlp**
* **Deno** (Lightweight JS runtime to handle YouTube challenge scripts for `yt-dlp`)
* **mpv**
* **curl**
* **awk**, **grep**, **sed**, **tr** (standard POSIX tools)

#### 📦 Simple Deno Installation:

Installing Deno is straightforward and takes less than a minute:

```bash
curl -fsSL https://deno.land/install.sh | sh
```

#### 📦 Simple yt-dpl Installation:

```bash
pipx install yt-dlp
```

*Garanta que os PATH das dependências estejam corretas e recarregue ou reinicie o bash/zash/ash*

---

### 🚀 Installation & Usage

1. Clone the repository:

   ```bash
   git clone https://github.com/pdropi/live-inicio.git
   cd live-inicio
   ```

2. Make the script executable:

   ```bash
   chmod +x live-inicio
   ```

3. Run the script with a live stream URL and target offset in seconds:

   * **Watch live stream from the current live point (or regular video from start):**

     ```bash
     ./live-inicio https://www.youtube.com/watch?v=EXAMPLE
     ```

   * **Start live stream from a specific offset (e.g., 2 hours / 7200 seconds):**

     ```bash
     ./live-inicio https://www.youtube.com/watch?v=EXAMPLE 7200
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
