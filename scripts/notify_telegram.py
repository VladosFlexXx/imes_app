#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Отправка уведомления о новом релизе в топик (ветку) Telegram-группы.
Поддерживает переменные окружения и аргументы командной строки.
"""

import os
import sys
import re
import json
import html
import argparse
import subprocess
import urllib.request
import urllib.error

DEFAULT_CHAT_ID = "-1003089297349"
DEFAULT_THREAD_ID = "28770"
DEFAULT_REPO = "VladosFlexXx/imes_app"
DEFAULT_FEEDBACK_URL = "https://t.me/t3w11"


def get_latest_tag_from_readme() -> str:
    """Извлекает последнюю версию из README_RU.md при отсутствии тега."""
    if os.path.exists("README_RU.md"):
        try:
            with open("README_RU.md", "r", encoding="utf-8") as f:
                content = f.read()
            m = re.search(r"### 🚀\s*(v?[0-9]+\.[0-9]+\.[0-9]+)", content)
            if m:
                tag = m.group(1).strip()
                return tag if tag.startswith("v") else f"v{tag}"
        except Exception:
            pass
    return "v0.6.4"


def extract_notes_for_tag(tag: str, notes_file: str = "release_notes.txt") -> str:
    """Извлекает описание релиза из файла release_notes.txt или README_RU.md."""
    if notes_file and os.path.exists(notes_file):
        try:
            with open(notes_file, "r", encoding="utf-8") as f:
                notes = f.read().strip()
                if notes:
                    return notes
        except Exception:
            pass

    clean_tag = tag.lstrip("v")
    if os.path.exists("README_RU.md"):
        try:
            with open("README_RU.md", "r", encoding="utf-8") as f:
                content = f.read()
            pattern = r"### 🚀\s*v?" + re.escape(clean_tag) + r"[^\n]*\n([\s\S]*?)(?=\n###|\n---|\Z)"
            m = re.search(pattern, content)
            if m:
                return m.group(1).strip()
        except Exception:
            pass

    try:
        git_tag_notes = subprocess.check_output(
            ["git", "tag", "-l", "--format=%(contents)", f"v{clean_tag}"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        if git_tag_notes:
            return git_tag_notes
    except Exception:
        pass

    return "В этом обновлении улучшена стабильность и исправлены ошибки."


def markdown_to_telegram_html(raw_text: str) -> str:
    """Безопасно переводит базовый markdown (жирный, курсив, код, списки) в HTML для Telegram."""
    # 1. Экранируем HTML-сущности (&, <, >)
    safe = html.escape(raw_text)

    # 2. **жирный** -> <b>жирный</b>
    safe = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", safe)

    # 3. `код` -> <code>код</code>
    safe = re.sub(r"`([^`\n]+)`", r"<code>\1</code>", safe)

    # 4. *курсив* -> <i>курсив</i>
    safe = re.sub(r"(?<!\w)\*([^*]+)\*(?!\w)", r"<i>\1</i>", safe)

    # 5. Маркеры списков "- " в начале строк -> красивый "• "
    lines = []
    for line in safe.splitlines():
        trimmed = line.strip()
        if trimmed.startswith("- "):
            lines.append("• " + trimmed[2:])
        elif trimmed.startswith("* "):
            lines.append("• " + trimmed[2:])
        else:
            lines.append(line)

    result = "\n".join(lines).strip()
    return result


def main():
    parser = argparse.ArgumentParser(description="Send Telegram release notification.")
    parser.add_argument("--tag", default=os.environ.get("TAG", ""), help="Release tag (e.g. v0.6.4)")
    parser.add_argument("--token", default=os.environ.get("TELEGRAM_BOT_TOKEN", ""), help="Telegram Bot Token")
    parser.add_argument("--chat-id", default=os.environ.get("TELEGRAM_CHAT_ID", DEFAULT_CHAT_ID), help="Telegram Chat ID")
    parser.add_argument("--thread-id", default=os.environ.get("TELEGRAM_THREAD_ID", DEFAULT_THREAD_ID), help="Telegram Topic Thread ID")
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", DEFAULT_REPO), help="GitHub Repo (owner/repo)")
    parser.add_argument("--feedback-url", default=os.environ.get("FEEDBACK_URL", DEFAULT_FEEDBACK_URL), help="Feedback Telegram URL")
    parser.add_argument("--notes-file", default=os.environ.get("RELEASE_NOTES_FILE", "release_notes.txt"), help="Path to release notes file")
    parser.add_argument("--dry-run", action="store_true", help="Print message instead of sending")

    args = parser.parse_args()

    tag = args.tag.strip()
    if not tag:
        tag = get_latest_tag_from_readme()

    # Гарантируем формат vX.X.X для ссылок и отображения
    tag_name = tag if tag.startswith("v") else f"v{tag}"

    token = args.token.strip()
    chat_id = args.chat_id.strip() or DEFAULT_CHAT_ID
    thread_id = args.thread_id.strip() or DEFAULT_THREAD_ID
    repo = args.repo.strip() or DEFAULT_REPO
    feedback_url = args.feedback_url.strip() or DEFAULT_FEEDBACK_URL

    print(f"Подготовка уведомления для релиза {tag_name}...")

    raw_notes = extract_notes_for_tag(tag_name, args.notes_file)
    html_notes = markdown_to_telegram_html(raw_notes)

    # Ограничение длины чейнджлога, чтобы уложиться в 4096 символов Telegram
    if len(html_notes) > 2500:
        html_notes = html_notes[:2500].rsplit("\n", 1)[0] + "\n<i>... (полный список изменений на GitHub)</i>"

    apk_url = f"https://github.com/{repo}/releases/download/{tag_name}/MyIMES-{tag_name}.apk"
    ipa_url = f"https://github.com/{repo}/releases/download/{tag_name}/MyIMES-{tag_name}.ipa"
    release_url = f"https://github.com/{repo}/releases/tag/{tag_name}"

    message_text = (
        f"🚀 <b>Мой ИМЭС {tag_name}</b>\n\n"
        f"✨ <b>Что нового в этой версии:</b>\n"
        f"{html_notes}\n\n"
        f"📥 <b>Скачать обновление:</b>\n"
        f"🤖 <b>Android:</b> <a href=\"{apk_url}\">MyIMES-{tag_name}.apk</a>\n"
        f"🍎 <b>iOS:</b> <a href=\"{ipa_url}\">MyIMES-{tag_name}.ipa</a>\n\n"
        f"💬 <b>Обратная связь:</b> Нашли баг или есть идея? <a href=\"{feedback_url}\">Напишите разработчику</a>\n\n"
        f"🔗 <a href=\"{release_url}\">Открыть страницу релиза на GitHub</a>"
    )

    inline_keyboard = [
        [
            {"text": "🤖 Скачать APK (Android)", "url": apk_url},
            {"text": "🍎 Скачать IPA (iOS)", "url": ipa_url},
        ],
        [
            {"text": "💡 Нашёл баг / есть идея", "url": feedback_url},
            {"text": "🐙 Релиз на GitHub", "url": release_url},
        ],
    ]

    payload = {
        "chat_id": chat_id,
        "text": message_text,
        "parse_mode": "HTML",
        "disable_web_page_preview": True,
        "reply_markup": {"inline_keyboard": inline_keyboard},
    }

    if thread_id and thread_id != "0":
        try:
            payload["message_thread_id"] = int(thread_id)
        except ValueError:
            pass

    if args.dry_run:
        print("\n--- [DRY-RUN] Сформированное сообщение ---")
        print(message_text)
        print("\n--- Payload ---")
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return

    if not token or not chat_id:
        print("⚠️ Предупреждение: TELEGRAM_BOT_TOKEN или TELEGRAM_CHAT_ID не заданы. Пропуск отправки в Telegram.")
        return

    api_url = f"https://api.telegram.org/bot{token}/sendMessage"
    headers = {"Content-Type": "application/json; charset=utf-8"}
    data_bytes = json.dumps(payload, ensure_ascii=False).encode("utf-8")

    req = urllib.request.Request(api_url, data=data_bytes, headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            res_data = json.loads(response.read().decode("utf-8"))
            if res_data.get("ok"):
                msg_id = res_data.get("result", {}).get("message_id")
                print(f"✅ Уведомление успешно отправлено в ветку {thread_id} группы {chat_id} (Message ID: {msg_id})")
            else:
                print(f"❌ Ошибка Telegram API: {res_data}")
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")
        print(f"❌ Ошибка отправки в Telegram (HTTP {e.code}): {error_body}")
    except Exception as e:
        print(f"❌ Непредвиденная ошибка: {e}")


if __name__ == "__main__":
    main()
