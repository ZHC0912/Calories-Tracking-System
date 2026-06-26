"""resolve_grams priority chain: user > bucket > estimate."""

from app.core.dishes import DISHES, GENERIC_DEFAULT_GRAMS
from app.core.portion import resolve_grams


def test_user_grams_win_over_everything():
    grams, source = resolve_grams("nasi lemak", user_grams=250, bucket="large")
    assert grams == 250.0
    assert source == "user"


def test_bucket_used_when_no_user_grams():
    grams, source = resolve_grams("nasi lemak", bucket="large")
    assert grams == DISHES["nasi lemak"]["bucket_grams"]["large"]
    assert source == "bucket"


def test_bucket_single_letter_alias():
    grams, source = resolve_grams("roti canai", bucket="s")
    assert grams == DISHES["roti canai"]["bucket_grams"]["small"]
    assert source == "bucket"


def test_default_when_no_hints():
    grams, source = resolve_grams("char kway teow")
    assert grams == DISHES["char kway teow"]["default_grams"]
    assert source == "estimate"


def test_dish_lookup_is_case_insensitive():
    grams, source = resolve_grams("Chicken  Rice")
    assert grams == DISHES["chicken rice"]["default_grams"]
    assert source == "estimate"


def test_unknown_dish_falls_back_to_generic_default():
    grams, source = resolve_grams("mystery soup")
    assert grams == GENERIC_DEFAULT_GRAMS
    assert source == "estimate"


def test_invalid_bucket_falls_through_to_default():
    grams, source = resolve_grams("nasi lemak", bucket="gigantic")
    assert grams == DISHES["nasi lemak"]["default_grams"]
    assert source == "estimate"


def test_zero_or_negative_user_grams_ignored():
    grams, source = resolve_grams("nasi lemak", user_grams=0)
    assert source == "estimate"
