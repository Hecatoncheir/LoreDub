# Платная версия LoreDub: модели

23 сентября 2026

## Вывод

Самый слышимый скачок дают три замены, и все три уже есть под лицензиями, разрешающими продажу: клонирующий TTS Qwen3-TTS вместо связки Vosk + OpenVoice, LLM-переводчик вместо Marian и распознавание Parakeet или Qwen3-ASR вместо whisper с флагом перевода. Платная версия тогда становится GPU-версией для карты от 8 ГБ, а нынешний CPU-стек остаётся бесплатным.

Деньги берутся не за веса, они открытые. Продаётся GPU-сборка, собственные дообучения, облачный тариф для тех, у кого нет карты, и поддержка.

## Кандидаты по этапам

Каждая строка сравнивает то, что стоит в каталоге сейчас, с лучшим кандидатом под лицензией, разрешающей продажу.

| Этап | Сейчас | Кандидат | Лицензия | Что меняется |
| --- | --- | --- | --- | --- |
| Распознавание | whisper medium / large-v3-turbo | [Parakeet-TDT-0.6B-v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3), 25 европейских языков с русским; [Qwen3-ASR-1.7B](https://huggingface.co/Qwen/Qwen3-ASR-1.7B), 30 языков | CC-BY-4.0 / Apache 2.0 | Parakeet: WER 6,34 % на Open ASR Leaderboard при RTFx 3 332. Qwen3-ASR обгоняет whisper large-v3 на LibriSpeech other и GigaSpeech. Перевод уходит из ASR в LLM |
| Распознавание потоком | нет | [Voxtral Realtime 4B](https://mistral.ai/news/voxtral-transcribe-2/), 13 языков с русским | Apache 2.0 | текст появляется до конца фразы, задержка настраивается до 200 мс |
| Русский оригинал | whisper | [GigaAM-v3](https://huggingface.co/ai-sage/GigaAM-v3), 240M | MIT | WER 8,4 % против 25,1 % у whisper large-v3 на русских наборах |
| Речь сразу в русский текст | нет | [Canary-1B-v2](https://huggingface.co/nvidia/canary-1b-v2), ASR и перевод en↔24 языка | CC-BY-4.0 | одна модель вместо двух, COMET 84,6 на Fleurs en→X; уступает LLM по контексту и глоссарию |
| Перевод | opus-mt-tc-big, Marian, 242 МБ | [TranslateGemma-12B](https://huggingface.co/google/translategemma-12b-it); для 8 ГБ [TranslateGemma-4B](https://huggingface.co/google/translategemma-4b-it) или [Gemma 4](https://opensource.googleblog.com/2026/03/gemma-4-expanding-the-gemmaverse-with-apache-20.html) E4B; альтернатива [Seed-X-PPO-7B](https://huggingface.co/ByteDance-Seed/Seed-X-PPO-7B), 28 языков | Gemma Terms; Apache 2.0 у Gemma 4; OpenMDW у Seed-X | контекст сцены, глоссарий в промпте, род говорящего |
| Голос и тембр | Vosk-ru 0.9 + OpenVoice V2 | [Qwen3-TTS-12Hz-1.7B-Base](https://github.com/QwenLM/Qwen3-TTS), 10 языков с русским | Apache 2.0 | клон с 3 секунд записи, первый звук через 97 мс, конвертер не нужен |
| Голос полегче |  | [Chatterbox Multilingual V3](https://github.com/resemble-ai/chatterbox), 500M, 23 языка; [Fun-CosyVoice 3](https://github.com/QwenAudio/CosyVoice), 0.5B, 9 языков | MIT; у CosyVoice Apache 2.0 на код, лицензию весов проверить | для карт на 6–8 ГБ; CosyVoice даёт поток с задержкой 150 мс |
| Кто говорит | энкодер OpenVoice, энергетический VAD | [WeSpeaker](https://github.com/wenet-e2e/wespeaker) или [3D-Speaker](https://github.com/modelscope/3D-Speaker) для отпечатков; [Silero VAD](https://github.com/snakers4/silero-vad); [pyannote community-1](https://huggingface.co/pyannote/speaker-diarization-community-1) или потоковый [Sortformer v2](https://huggingface.co/nvidia/diar_streaming_sortformer_4spk-v2) для разрезания диалога | Apache 2.0 / MIT / CC-BY-4.0 | банк голосов устойчивее, фраза под музыкой не рвётся |

## Качество перевода en→ru

Локальная 12B-модель уже обгоняет Google Translate на WMT24++ в направлении en→ru. Цифры XCOMET взяты из [статьи MiLMMT](https://arxiv.org/html/2602.11961v2); Marian в неё не входит и такого класса не достигает.

| Система | XCOMET, en→ru | Лицензия |
| --- | --- | --- |
| Gemini 3 Pro | 86,5 | облако |
| TranslateGemma-12B | 85,5 | Gemma Terms |
| Google Translate | 84,7 | облако |
| MiLMMT-46-12B | 84,2 | Gemma Terms |
| MiLMMT-46-4B | 82,7 | Gemma Terms |
| MiLMMT-46-1B | 75,5 | Gemma Terms |

## Что получает игрок от LLM-переводчика

За это платят, а не за саму модель: Marian переводит строку без контекста, LLM переводит сцену.

- **Род говорящего.** Воркер уже оценивает пол по тону. В промпте это даёт «я пошла» вместо «я пошёл»; Marian этого не умеет в принципе.
- **Контекст предыдущих реплик.** Правильные местоимения, ты/вы, кто с кем говорит.
- **Глоссарий как часть промпта.** Имена склоняются по падежам, а не подставляются в именительном.
- **Любой язык игры.** Перевод больше не привязан к тому, что умеет whisper с флагом перевода, и открывается дубляж русских игр на английский.
- **Правки на лету.** Запись в словаре становится строкой промпта и действует со следующей реплики, как сейчас.

## Что исключено и почему

Отбор шёл по одному правилу: дубляж должен оставаться свободным для заработка, как при отказе от Silero.

| Модель | Причина |
| --- | --- |
| [Tower+ 9B](https://huggingface.co/Unbabel/Tower-Plus-9B) | CC-BY-NC-SA-4.0, продажа запрещена |
| [HY-MT1.5](https://github.com/Tencent-Hunyuan/HY-MT/blob/main/License.txt) от Tencent | лицензия исключает ЕС, Британию и Южную Корею; для СНГ годится, для продаж по миру нет |
| XTTS-v2, Fish/OpenAudio, веса F5-TTS, Silero | некоммерческие лицензии |
| [Seed-VC](https://github.com/Plachtaa/seed-vc) | GPL-3.0, та же причина, по которой не взяли espeak-ng |
| [Vevo2](https://github.com/open-mmlab/Amphion/blob/main/models/svc/vevo2/README.md) | обучен на Emilia, русского там нет |
| Kokoro, Orpheus, Zonos, Dia | русского нет |
| Sortformer 4spk-v1 от NVIDIA | CC-BY-NC-4.0, только некоммерческое использование; потоковый v2 вышел под CC-BY-4.0 и годится |

## Железо

Ориентировочный расход памяти карты по трём профилям; точные цифры даст измерение.

| Карта | Распознавание | Перевод | Голос | Итого, ГБ |
| --- | --- | --- | --- | --- |
| 8 ГБ | Parakeet 0.6B | TranslateGemma-4B, Q4 | Qwen3-TTS 0.6B | ≈6 |
| 12 ГБ | Parakeet 0.6B | TranslateGemma-4B, Q4 | Qwen3-TTS 1.7B, fp16 | ≈9 |
| 16 ГБ и выше | Qwen3-ASR 1.7B | TranslateGemma-12B, Q4 | Qwen3-TTS 1.7B, fp16 | ≈14 |

Qwen3-TTS 1.7B в fp16 занимает около 4,2 ГБ. Qwen3-TTS и переводчик ложатся в уже существующий рантайм torch-cuda воркера; для LLM безопаснее всего llama.cpp отдельным процессом, по образцу whisper.cpp. Стриминг TTS компенсирует то, что LLM переводит строку дольше, чем Marian.

## Что на самом деле продаётся

Веса под Apache, MIT и CC-BY может забрать любой конкурент, поэтому деньги берутся за то, чего у него нет.

- **GPU-сборка.** Закрытый премиум-модуль рядом с MIT-ядром; MIT это допускает.
- **Собственные дообучения.** Qwen3-TTS, дообученный на выразительной игровой русской речи, можно держать закрытым. LoRA для переводчика на Gemma остаётся под Gemma Terms, но продавать и гейтить её можно. Официальные локализации игр как обучающие данные рискованны по авторскому праву; безопаснее синтетика от большой модели или лицензированные корпуса.
- **Облачный тариф.** Тот же стек на своём сервере по подписке для тех, у кого нет карты. Таких игроков большинство, и с открытыми весами именно подписка обычно приносит деньги.
- **Свои ключи к ElevenLabs или DeepL** как потолок качества. Это ломает принцип «всё локально», поэтому только как опция.

Обязанности по лицензиям: CC-BY требует упоминания в NOTICE, как уже делается для переводчиков; Gemma Terms передаются дальше вместе с моделью; OpenMDW у Seed-X прочитать перед выпуском.

## Следующий шаг: измерить

Решение принимается по измерению, как в ADR, а не по статьям.

- [ ] Клон Qwen3-TTS-1.7B против Vosk + OpenVoice на тех же четырёх персонажах и той же метрике сходства, где сейчас 0,743, плюс на слух. Туда же Chatterbox V3: прошлый Chatterbox отпал из-за 5 с на строку, с тех пор вышли три версии.
- [ ] TranslateGemma-4B и 12B и Gemma 4 против Marian на полусотне игровых реплик с родом и глоссарием в промпте.
- [ ] Parakeet v3 против whisper на захваченном звуке игры с музыкой, с Silero VAD и без.

## Источники

- [Qwen3-TTS](https://github.com/QwenLM/Qwen3-TTS), [релиз Qwen3-TTS](https://qwen.ai/blog?id=qwen3tts-0115)
- [Chatterbox](https://github.com/resemble-ai/chatterbox)
- [CosyVoice](https://github.com/QwenAudio/CosyVoice)
- [Parakeet-TDT-0.6B-v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)
- [Qwen3-ASR-1.7B](https://huggingface.co/Qwen/Qwen3-ASR-1.7B), [релиз Qwen3-ASR](https://qwen.ai/blog?id=qwen3asr)
- [Voxtral Transcribe 2](https://mistral.ai/news/voxtral-transcribe-2/)
- [Canary-1B-v2](https://huggingface.co/nvidia/canary-1b-v2)
- [GigaAM-v3](https://huggingface.co/ai-sage/GigaAM-v3)
- [Статья MiLMMT с таблицей en→ru](https://arxiv.org/html/2602.11961v2), [MiLMMT-46-12B](https://huggingface.co/xiaomi-research/MiLMMT-46-12B-v1.0)
- [TranslateGemma-12B](https://huggingface.co/google/translategemma-12b-it)
- [Gemma 4 под Apache 2.0](https://opensource.googleblog.com/2026/03/gemma-4-expanding-the-gemmaverse-with-apache-20.html)
- [Seed-X-PPO-7B](https://huggingface.co/ByteDance-Seed/Seed-X-PPO-7B)
- [Лицензия HY-MT](https://github.com/Tencent-Hunyuan/HY-MT/blob/main/License.txt)
- [Tower-Plus-9B](https://huggingface.co/Unbabel/Tower-Plus-9B)
- [Seed-VC](https://github.com/Plachtaa/seed-vc), [Vevo2](https://github.com/open-mmlab/Amphion/blob/main/models/svc/vevo2/README.md)
- [Open ASR Leaderboard](https://huggingface.co/blog/open-asr-leaderboard)
