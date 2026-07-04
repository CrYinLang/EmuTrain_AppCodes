"""搜索核心逻辑 - 从 Flutter 代码移植"""

import re
from math import inf


def clean_string(s: str) -> str:
    """去除非字母数字字符并转大写"""
    return re.sub(r"[^a-zA-Z0-9]", "", s).upper()


def extract_last_four(text: str | None) -> str | None:
    """提取末四位数字"""
    if not text:
        return None
    digits = re.sub(r"[^0-9]", "", text)
    return digits[-4:] if len(digits) >= 4 else None


def calculate_match_score(input_str: str, train_number: str, model_code: str) -> float:
    """计算输入与车组的匹配分数 (0.0 ~ 1.0)"""
    cleaned_input = clean_string(input_str)
    cleaned_train = clean_string(train_number)
    cleaned_model = clean_string(model_code)

    full_number = f"{cleaned_model}{cleaned_train}"
    if cleaned_input == full_number:
        return 1.0

    # 数字部分评分
    number_score = 0.0
    if cleaned_train:
        if cleaned_input.endswith(cleaned_train):
            number_score = 1.0
        elif len(cleaned_train) >= 4:
            last_four = cleaned_train[-4:]
            if last_four in cleaned_input:
                number_score = 0.8

    # 车型部分评分
    model_score = 0.0
    if cleaned_input.startswith(cleaned_model):
        model_score = 1.0
    elif cleaned_model.startswith(cleaned_input):
        model_score = len(cleaned_input) / len(cleaned_model) if cleaned_model else 0
    else:
        common = 0
        for i in range(min(len(cleaned_input), len(cleaned_model))):
            if cleaned_input[i] == cleaned_model[i]:
                common += 1
            else:
                break
        if common >= 4:
            model_score = common / len(cleaned_model) if cleaned_model else 0
        elif common >= 2:
            model_score = (common / len(cleaned_model) * 0.6) if cleaned_model else 0

    # 综合评分
    if number_score > 0 and model_score > 0:
        final = number_score * 0.7 + model_score * 0.3
    elif number_score > 0:
        final = number_score * 0.5
    elif model_score > 0:
        final = model_score * 0.4
    else:
        final = 0.0

    return max(0.0, min(1.0, final))


def score_and_select(train_data: list[dict], input_str: str) -> list[dict] | None:
    """
    车号本地模糊匹配 + 评分。
    返回 None 表示完全无匹配。
    返回空 list 表示有粗筛但无精筛。
    """
    cleaned_input = clean_string(input_str)
    input_digits = re.sub(r"[^0-9]", "", cleaned_input)
    has_four_digits = len(input_digits) >= 4

    # 粗筛
    matches = [
        r for r in train_data
        if cleaned_input in clean_string(r.get("车组号", ""))
        or clean_string(r.get("车组号", "")) in cleaned_input
    ]
    if not matches:
        return []

    # 评分
    scored: list[tuple[dict, float]] = []
    for r in matches:
        model = r.get("type_code", "")
        number = r.get("车组号", "")
        score = calculate_match_score(input_str, number, model)

        if has_four_digits:
            input_last4 = input_digits[-4:]
            record_last4 = extract_last_four(number)
            if record_last4 != input_last4:
                continue
        scored.append((r, score))

    if not scored:
        return None

    scored.sort(key=lambda x: x[1], reverse=True)
    top_score = scored[0][1]

    if top_score >= 0.9:
        return [r for r, s in scored if s >= top_score - 0.05]
    else:
        return [r for s, (r, _) in zip(range(5), scored)]


def filter_by_bureau(train_data: list[dict], bureau_input: str) -> list[dict]:
    """路局过滤"""
    pattern = bureau_input.strip().lower()
    matched = [
        r for r in train_data
        if pattern in (r.get("配属路局") or "").lower()
    ]
    matched.sort(key=lambda r: (r.get("type_code", ""), r.get("车组号", "")))
    return matched


def filter_by_car_type(train_data: list[dict], car_type: str) -> list[dict]:
    """车型过滤"""
    pattern = car_type.strip().upper()
    matched = [r for r in train_data if (r.get("type_code") or "").upper() == pattern]
    matched.sort(key=lambda r: r.get("车组号", ""))
    return matched


def filter_by_depot(train_data: list[dict], depot_input: str) -> list[dict]:
    """动车所过滤"""
    pattern = depot_input.strip().lower()
    matched = [
        r for r in train_data
        if (r.get("配属动车所") or "").strip() and pattern in (r.get("配属动车所") or "").lower()
    ]
    matched.sort(key=lambda r: (r.get("type_code", ""), r.get("车组号", "")))
    return matched


def filter_by_loco_depot(loco_data: list[dict], depot_input: str) -> list[dict]:
    """机车配属段过滤"""
    pattern = depot_input.strip().lower()
    return [
        r for r in loco_data
        if pattern in (r.get("配属段") or "").lower()
    ]


def filter_by_coach_owner(coach_data: list[dict], owner_input: str) -> list[dict]:
    """客车配属过滤"""
    pattern = owner_input.strip().lower()
    return [
        r for r in coach_data
        if pattern in (r.get("现配属") or "").lower()
    ]
