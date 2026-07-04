"""车型图标映射 - 完整移植自 Flutter gallery_page.dart 的 getTrainIconModel"""


def get_train_icon_model(model: str, number: str) -> str:
    """根据车型和车号返回图标文件名（不含扩展名）"""
    model_c = model.strip()
    cleaned_number = number.strip()
    digits = ""
    for c in cleaned_number:
        if c.isdigit():
            digits += c
    num = int(digits) if digits else None

    # ---- 特殊车号映射 ----

    if model_c == "CRH6A" and num is not None:
        if (401 <= num <= 408) or (602 <= num <= 610) or num in (420, 421):
            return "CRH6-2"

    if model_c == "CRH3A-A" and num is not None:
        if 511 <= num <= 521:
            return "CRH3A-A-GKCJ"
        if 524 <= num <= 528:
            return "CRH3A-A-ZKCJ"

    if model_c == "CRH1B" and num is not None:
        if 1076 <= num <= 1080:
            return "CRH1E"

    if model_c == "CRH1E" and num is not None:
        if 1229 <= num <= 1233:
            return "CRH1A-A"

    if model_c == "CRH6F" and num is not None:
        if 409 <= num <= 413:
            return "CRH6F"
        if 430 <= num <= 435:
            return "CRH6F"
        if num == 4512:
            return "CRH6-2"
        if num == 1:
            return "CRH6-2"

    if model_c == "CRH6F-A" and num is not None:
        if 445 <= num <= 450:
            return "CRH6F"
        return "CRH6A"

    if "CRH6F" in model_c:
        return "CRH6A"

    if model_c == "CRH2A" and num is not None:
        if num == 2460:
            return "CRH2A-2460"

    if model_c == "CR400BF" and num is not None:
        if num == 31:
            return "CR400BF-0031"
        if num == 5162:
            return "CR400BF-C-5162"
        if 5154 <= num <= 5161:
            return "CR400BF-C"
        if num == 5051:
            return "CR400BF-G-0051"
        if num == 5001:
            return "CR400BF-J-0001"
        if num == 5003:
            return "CR400BF-J-0003"
        if 5052 <= num <= 5058:
            return "CR400BF-S"
        if num == 5524:
            return "CR400BF-Z-0524"
        if 5501 <= num <= 5523:
            return "CR400BF-Z"

    if model_c == "CR400AF" and num is not None:
        if 2029 <= num <= 2032:
            return "CR400AF-J"
        if 2033 <= num <= 2042:
            return "CR400AF-SZE"

    if model_c == "CRH380A" and num is not None:
        if 2569 <= num <= 2590:
            return "CRH380AM"
        if 2637 <= num <= 2640:
            return "CRH380AD"
        if 2641 <= num <= 2646:
            return "CRH380AJ"
        if 251 <= num <= 259:
            return "CRH380AD"

    if model_c == "CRH380B" and num is not None:
        if 3569 <= num <= 3578:
            return "CRH380BJ"
        if 5717 <= num <= 5726:
            return "CRH380BJ-A"

    # ---- 带后缀的车型直接映射 ----

    if model_c == "CR400BF-J":
        if num == 1:
            return "CR400BF-J-0001"
        if num == 3:
            return "CR400BF-J-0003"
        return "CR400BF-J-0001"  # 默认用0001的图标

    if model_c == "CR400AF-J":
        return "CR400AF-J"

    if model_c == "CR400BF-C":
        if num is not None and num == 5162:
            return "CR400BF-C-5162"
        return "CR400BF-C"

    if model_c == "CR400BF-G" and num is not None:
        if num == 51:
            return "CR400BF-G-0051"
        return "CR400BF"

    if model_c == "CR400BF-S":
        return "CR400BF-S"

    if model_c == "CR400BF-Z" and num is not None:
        if num == 524:
            return "CR400BF-Z-0524"
        return "CR400BF-Z"

    if model_c == "CRH380AJ":
        return "CRH380AJ"

    if model_c == "CRH380BJ" and num is not None:
        return "CRH380BJ"

    if model_c == "CRH380BJ-A":
        return "CRH380BJ-A"

    if model_c == "CRH380AM":
        return "CRH380AM"

    if model_c == "CRH5J":
        return "CRH5J"

    if model_c == "CRH2J":
        return "CRH2J"

    # ---- 车型名称映射 ----

    if model_c == "CRH1B":
        return "CRH1A"
    if model_c == "CRH3A" and num is not None and num in (302, 502):
        return "CRH3A-YC"
    if model_c in ("CRH380AL", "CRH380AN"):
        return "CRH380A"

    if model_c == "CRH2B" and num is not None:
        if (2466 <= num <= 2472) or (4096 <= num <= 4105):
            return "CRH2A"
        return "CRH2BE"

    if model_c == "CRH5G" and num is not None:
        if 5218 <= num <= 5229:
            return "CRH5G"
        return "CRH5A"
    if model_c == "CRH5G":
        return "CRH5A"

    if model_c == "CR200JD":
        return "CR200JC"

    if model_c == "CRH2E" and num is not None and num in (2461, 2462):
        return "CRH2E-NG"
    if model_c == "CRH2G":
        return "CRH2E-NG"
    if model_c == "CRH2E":
        return "CRH2BE"

    if model_c in ("CRH380BL", "CRH380BG"):
        return "CRH380B"

    if model_c == "CRH2C" and num is not None and num == 2150:
        return "CRH380A"

    if model_c == "CRH6A-A" or model_c == "CRH6A-AZ":
        return "CRH6A"

    # ---- 涂装/变体映射 ----

    if model_c in ("CR400AF-Z", "CR400AF-AZ", "CR400AF-BZ",
                    "CR400AF-S", "CR400AF-AS", "CR400AF-BS",
                    "CR400AF-AE", "CR400AF-C"):
        return "CR400AF-SZE"

    if model_c in ("CR400BF-S", "CR400BF-AS", "CR400BF-BS", "CR400BF-GS"):
        return "CR400BF-S"

    if model_c in ("CR400BF-Z", "CR400BF-AZ", "CR400BF-BZ", "CR400BF-GZ"):
        return "CR400BF-Z"

    if model_c in ("CR400AF-A", "CR400AF-B", "CR400AF-G"):
        return "CR400AF"

    if model_c in ("CR400BF-A", "CR400BF-B", "CR400BF-G"):
        return "CR400BF"

    if model_c == "CR400BF-G" and num is not None and num == 51:
        return "CR400BF-0031"

    # 默认返回车型名
    return model_c


def get_train_icon_path(model: str, number: str) -> str:
    """返回完整的图标路径（相对于 /assets/）"""
    icon_model = get_train_icon_model(model, number)
    return f"icon/train/{icon_model}.png"
