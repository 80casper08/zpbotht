import os
import asyncio
from aiogram import Bot, Dispatcher, types, F
from aiogram.types import ReplyKeyboardMarkup, KeyboardButton
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.fsm.storage.memory import MemoryStorage
from fastapi import FastAPI, Request
from aiogram.webhook.aiohttp_server import SimpleRequestHandler, setup_application
import uvicorn

TOKEN = os.getenv("TOKEN2")
WEBHOOK_PATH = "/webhook"
WEBHOOK_URL = "https://zpbotht-gn56.onrender.com" # Наприклад: https://hardtest3-1.onrender.com/webhook
GROUP_ID = -1002786428793

bot = Bot(token=TOKEN)
dp = Dispatcher(storage=MemoryStorage())

# --- Стани ---
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
SHIFT_OPTIONS = [5, 6, 7, 8, 9, 10]
OVERTIME_OPTIONS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

def get_shift_keyboard():
    return ReplyKeyboardMarkup(
        keyboard=[[KeyboardButton(text=str(num))] for num in SHIFT_OPTIONS],
        resize_keyboard=True
    )

def get_overtime_keyboard():
    return ReplyKeyboardMarkup(
        keyboard=[[KeyboardButton(text=str(num))] for num in OVERTIME_OPTIONS],
        resize_keyboard=True
    )

start_kb = ReplyKeyboardMarkup(keyboard=[[KeyboardButton(text="▶️ Старт")]], resize_keyboard=True)

# --- Хендлери ---
@dp.message(F.text == "/start")
@dp.message(F.text == "▶️ Старт")
async def start(message: types.Message, state: FSMContext):
    buttons = [[KeyboardButton(text=grade)] for grade in GRADE_DATA]
    await message.answer("👷 Вибери свій грейд:", reply_markup=ReplyKeyboardMarkup(keyboard=buttons, resize_keyboard=True))
    await state.set_state(SalaryForm.grade)

@dp.message(SalaryForm.grade)
async def get_grade(message: types.Message, state: FSMContext):
    grade = message.text
    if grade not in GRADE_DATA:
        await message.answer("⚠️ Невірний грейд. Обери з кнопок.")
        return
    await state.update_data(grade=grade)
    await message.answer("🔢 Введи кількість денних змін:", reply_markup=get_shift_keyboard())
    await state.set_state(SalaryForm.day_shifts)

@dp.message(SalaryForm.day_shifts)
async def get_day_shifts(message: types.Message, state: FSMContext):
    try:
        day_shifts = int(message.text)
        await state.update_data(day_shifts=day_shifts)
        await message.answer("🌙 Введи кількість нічних змін:", reply_markup=get_shift_keyboard())
        await state.set_state(SalaryForm.night_shifts)
    except:
        await message.answer("Введи число або обери з кнопок.", reply_markup=get_shift_keyboard())

@dp.message(SalaryForm.night_shifts)
async def get_night_shifts(message: types.Message, state: FSMContext):
    try:
        night_shifts = int(message.text)
        await state.update_data(night_shifts=night_shifts)
        await message.answer("⏱️ Введи кількість овертаймів:", reply_markup=get_overtime_keyboard())
        await state.set_state(SalaryForm.overtime_shifts)
    except:
        await message.answer("Введи число або обери з кнопок.", reply_markup=get_shift_keyboard())

@dp.message(SalaryForm.overtime_shifts)
async def get_overtime_shifts(message: types.Message, state: FSMContext):
    try:
        overtime = int(message.text)
        await state.update_data(overtime_shifts=overtime)

        buttons = [[KeyboardButton(text=f"{percent}%")] for percent in PERCENT_OPTIONS]
        buttons.append([KeyboardButton(text="Ввести вручну")])
        await message.answer("🎯 Обери відсоток премії або введи вручну (наприклад, 80):",
                             reply_markup=ReplyKeyboardMarkup(keyboard=buttons, resize_keyboard=True))
        await state.set_state(SalaryForm.bonus_percent)
    except:
        await message.answer("Введи число або обери з кнопок.", reply_markup=get_overtime_keyboard())

@dp.message(SalaryForm.bonus_percent)
async def get_bonus_percent(message: types.Message, state: FSMContext):
    try:
        percent = int(message.text.replace("%", ""))
        if not 0 <= percent <= 200:
            raise ValueError
        data = await state.get_data()
        grade = data["grade"]
        day = data["day_shifts"]
        night = data["night_shifts"]
        overtime = data["overtime_shifts"]
        monthly_rate = GRADE_DATA[grade]["monthly"]
        base_bonus = GRADE_DATA[grade]["bonus"]

        hourly_rate = monthly_rate / 168
        day_salary = day * 11 * hourly_rate
        night_salary = night * ((3 * hourly_rate) + (8 * hourly_rate * 1.2))
        overtime_salary = overtime * 11 * hourly_rate * 2
        bonus = base_bonus * (percent / 100)

        total = round(day_salary + night_salary + overtime_salary + bonus)

        await message.answer(
            f"💼 Грейд: {grade}\n"
            f"☀️ Денних змін: {day}\n"
            f"🌙 Нічних змін: {night}\n"
            f"🕒 Овертаймів: {overtime}\n"
            f"🎁 Премія: {percent}%\n\n"
            f"💸 Загальна зарплата: {total} грн",
            reply_markup=start_kb
        )
        await state.clear()
    except:
        await message.answer("⚠️ Введи коректне число або скористайся кнопками.")

# --- FastAPI ---
app = FastAPI()

@app.get("/")
async def root():
    return {"message": "✅ Бот працює 24/7!"}

# --- Інтегруємо Aiogram з FastAPI ---
SimpleRequestHandler(dispatcher=dp, bot=bot).register(app, path=WEBHOOK_PATH)

# --- Запускаємо ---
if __name__ == "__main__":
    async def on_startup():
        await bot.set_webhook(WEBHOOK_URL + WEBHOOK_PATH)
    dp.startup.register(on_startup)
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
