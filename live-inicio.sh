#!/bin/bash
# uso: live-inicio "URL" [segundos_iniciais]
#   - sem tempo: abre normalmente (live no ponto atual / vídeo do começo)
#   - com tempo: live desde o início, pedindo direto os fragmentos a partir do ponto

DIR_SCRIPT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

live_inicio() (
  local URL="$1"
  local START="$2"

  if [ -z "$URL" ]; then
    echo "uso: live-inicio URL [start_em_segundos]"
    exit 1
  fi
  if [ -n "$START" ] && ! [[ "$START" =~ ^[0-9]+$ ]]; then
    echo "O tempo deve ser em segundos (número inteiro)."
    exit 1
  fi

  cd "$DIR_SCRIPT" || exit 1
  RC=(--remote-components ejs:github)

  cat > "$DIR_SCRIPT/.seekwatch.lua" <<'EOF'
local last = nil
mp.observe_property("time-pos", "number", function(_, t)
  if t == nil then return end
  if last and math.abs(t - last) > 3 then
    print(string.format("[SEEK] %s: %.1fs -> %.1fs",
      (t > last) and "avanço" or "retrocesso", last, t))
  end
  last = t
end)
EOF

  STATUS=$(yt-dlp "${RC[@]}" --no-warnings --print live_status "$URL" 2>/dev/null | tail -n 1)
  echo "Status: ${STATUS:-desconhecido}"

  # ---------- vídeo comum, live encerrada, ou live sem tempo ----------
  if { [ "$STATUS" != "is_live" ] && [ "$STATUS" != "post_live" ]; } || [ -z "$START" ]; then
    MPV_START=()
    [ -n "$START" ] && MPV_START=(--start="$START")
    mpv "${MPV_START[@]}" \
      --script="$DIR_SCRIPT/.seekwatch.lua" \
      --ytdl-raw-options=remote-components=ejs:github \
      --ytdl-format="bestvideo[height<=480]+bestaudio/best[height<=480]" \
      "$URL"
    exit 0
  fi

  # ---------- live em andamento: pede os fragmentos direto pelo número ----------
  #manter este comentário. Aumentar a variável LOTE abaixo pode baixar o vídeo mais rápido, mas, pode dar umas travadas se o processador for fraco. em computador antigo estabilizou com 2, que dá 4 urls por vez
  LOTE=2
  MIN_V=200000
  MIN_A=30000

  echo "Obtendo URLs..."
  mapfile -t URLS < <(yt-dlp "${RC[@]}" --live-from-start --no-warnings -f "135,140" -g "$URL" 2>/dev/null)
  UV="${URLS[0]}"
  UA="${URLS[1]}"
  case "$UV" in *itag=135*) ;; *) echo "URL de vídeo inesperada (esperava itag=135)."; exit 1 ;; esac
  case "$UA" in *itag=140*) ;; *) echo "URL de áudio inesperada (esperava itag=140)."; exit 1 ;; esac

  buscar() { curl -sf --retry 3 --max-time 60 "$1&sq=$2" -o "$3"; }

  rm -f live_v.mp4 live_a.m4a .p_* .t_v .t_a .hdr .fv .fa

  curl -sf --retry 3 --max-time 60 -D .hdr "$UV&sq=0" -o live_v.mp4 &
  curl -sf --retry 3 --max-time 60 "$UA&sq=0" -o live_a.m4a &
  wait
  if [ ! -s live_v.mp4 ] || [ ! -s live_a.m4a ]; then
    echo "Falhou ao baixar o fragmento 0."
    exit 1
  fi

  HDR=$(tr -d '\r' < .hdr)
  HSEQ=$(echo "$HDR" | awk -F': ' 'tolower($1)=="x-head-seqnum"{print $2}')
  HMS=$(echo "$HDR"  | awk -F': ' 'tolower($1)=="x-head-time-millis"{print $2}')
  if [ -n "$HSEQ" ] && [ "${HSEQ:-0}" -gt 0 ] && [ -n "$HMS" ]; then
    DUR=$(awk -v m="$HMS" -v s="$HSEQ" 'BEGIN{printf "%.3f", m/s/1000}')
  else
    DUR=5
    echo "[aviso] não consegui medir a duração do fragmento; usando 5s."
  fi
  SEQ0=$(awk -v t="$START" -v d="$DUR" 'BEGIN{printf "%d", t/d}')
  echo "Fragmento de ~${DUR}s; começando no fragmento $SEQ0 (ao vivo está em ${HSEQ:-?})"

  if [ -n "$HSEQ" ] && [ "$SEQ0" -ge "$HSEQ" ]; then
    echo "O tempo pedido (${START}s) é maior que a idade da live (~$(awk -v h="$HSEQ" -v d="$DUR" 'BEGIN{printf "%d", h*d}')s)."
    exit 1
  fi

  # tempo > 5s: tenta descartar o fragmento 0, se o fragmento do ponto pedido trouxer o próprio cabeçalho (moov)
  if [ "$START" -gt 5 ] && [ "$SEQ0" -ge 1 ]; then
    buscar "$UV" "$SEQ0" .t_v &
    buscar "$UA" "$SEQ0" .t_a &
    wait
    if [ -s .t_v ] && [ -s .t_a ] && grep -qa moov .t_v && grep -qa moov .t_a; then
      : > live_v.mp4
      : > live_a.m4a
      echo "Fragmento 0 descartado."
    else
      echo "[aviso] fragmento $SEQ0 sem cabeçalho; mantendo o fragmento 0."
    fi
    rm -f .t_v .t_a
  fi

  # Variáveis globais de controle de processos para o trap
  PID_F=""
  PID_TV=""
  PID_TA=""

  # download em lotes; vídeo é anexado antes do áudio
  (
    # pede novas URLs ao yt-dlp (usadas quando as atuais expiram)
    renovar() {
      local novas nv na
      mapfile -t novas < <(yt-dlp "${RC[@]}" --live-from-start --no-warnings -f "135,140" -g "$URL" 2>/dev/null)
      nv="${novas[0]}"
      na="${novas[1]}"
      case "$nv" in *itag=135*) ;; *) return 1 ;; esac
      case "$na" in *itag=140*) ;; *) return 1 ;; esac
      UV="$nv"
      UA="$na"
      return 0
    }

    # código HTTP de um fragmento (000 se nem conectou)
    codigo() { curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$1&sq=$2"; }

    n=$SEQ0
    [ "$n" -lt 1 ] && n=1
    while true; do
      rm -f .p_*
      for k in $(seq 0 $((LOTE - 1))); do
        buscar "$UV" $((n + k)) ".p_v$k" &
        buscar "$UA" $((n + k)) ".p_a$k" &
      done
      wait
      ok=0
      for k in $(seq 0 $((LOTE - 1))); do
        if [ -s ".p_v$k" ] && [ -s ".p_a$k" ]; then ok=$((ok + 1)); else break; fi
      done
      for k in $(seq 0 $((ok - 1))); do cat ".p_v$k" >> live_v.mp4; done
      for k in $(seq 0 $((ok - 1))); do cat ".p_a$k" >> live_a.m4a; done
      n=$((n + ok))

      if [ "$ok" -lt "$LOTE" ]; then
        sleep 2
        # lote incompleto: pode ser só o ao vivo ainda sem o fragmento, ou URL expirada.
        # testa o fragmento que faltou (n já aponta para ele)
        expirou=0
        if [ ! -s ".p_v$ok" ]; then
          case "$(codigo "$UV" "$n")" in 401|403|410) expirou=1 ;; esac
        fi
        if [ "$expirou" -eq 0 ] && [ ! -s ".p_a$ok" ]; then
          case "$(codigo "$UA" "$n")" in 401|403|410) expirou=1 ;; esac
        fi
        if [ "$expirou" -eq 1 ]; then
          echo "[aviso] URL expirada; renovando..." >&2
          if renovar; then
            echo "[aviso] URL renovada." >&2
          else
            echo "[aviso] falha ao renovar a URL; tentando de novo em 10s." >&2
            sleep 10
          fi
        fi
      fi
    done
  ) &
  PID_F=$!

  limpar() {
    kill "$PID_F" "$PID_TV" "$PID_TA" 2>/dev/null
    [ -n "$PID_F" ] && pkill -P "$PID_F" 2>/dev/null
    rm -f .p_* .t_v .t_a .hdr .fv .fa
  }
  trap 'limpar; exit 130' INT TERM
  trap limpar EXIT

  echo "Aguardando os primeiros dados..."
  until [ "$(stat -c %s live_v.mp4 2>/dev/null || echo 0)" -gt "$MIN_V" ] && \
        [ "$(stat -c %s live_a.m4a 2>/dev/null || echo 0)" -gt "$MIN_A" ]; do
    sleep 1
  done

  # FIFOs alimentados por "tail -f": o mpv espera por dados novos em vez de chegar ao fim do arquivo
  mkfifo .fv .fa
  tail -c +1 -f live_v.mp4 > .fv 2>/dev/null &
  PID_TV=$!
  tail -c +1 -f live_a.m4a > .fa 2>/dev/null &
  PID_TA=$!

  mpv --script="$DIR_SCRIPT/.seekwatch.lua" \
      --msg-level=ffmpeg/demuxer=error \
      --loop-file=no --loop-playlist=no --keep-open=no \
      --cache=yes --demuxer-max-bytes=100MiB --demuxer-max-back-bytes=100MiB \
      --audio-file=.fa .fv
)

live_inicio "$@"
