import asyncio
import os
from aiogram import Bot, Dispatcher, types, F
from aiogram.types import ReplyKeyboardMarkup, KeyboardButton
from aiogram.fsm.context import FSMContext
from aiogram.fsm.storage.memory import MemoryStorage
from aiogram.fsm.state import State, StatesGroup
from aiohttp import web

TOKEN = os.getenv("TOKEN")
bot = Bot(token=TOKEN)
dp = Dispatcher(storage=MemoryStorage())

class SalaryForm(StatesGroup):
    grade = State()
    day_shifts = State()
    night_shifts = State()
    overtime_shifts = State()
    bonus_percent = State()

GRADE_DATA = {
    "Low": {"monthly": 16800, "bonus": 4100},
    "Middle": {"monthly": 17500, "bonus": 4400},
    "High": {"monthly": 18500, "bonus": 4500}
}
PERCENT_OPTIONS = [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50]
start_kb = ReplyKeyboardMarkup([[KeyboardButton("▶️ Старт")]], resize_keyboard=True)

# (далі весь твій код handlers...)

async def run_web():
    async def handle(request):
        return web.Response(text="Бот працює!")
    app = web.Application()
    app.router.add_get("/", handle)
    runner = web.AppRunner(app)
    await runner.setup()
    await web.TCPSite(runner, "0.0.0.0", 8080).start()

async def main():
    await run_web()
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())
