"""Caption parsing: items + optional grams, single and multiple."""

from app.core.caption import parse_caption


def test_single_item_no_grams():
    items = parse_caption("nasi lemak")
    assert len(items) == 1
    assert items[0].name == "nasi lemak"
    assert items[0].grams is None


def test_single_item_with_grams():
    items = parse_caption("nasi lemak 250g")
    assert items[0].name == "nasi lemak"
    assert items[0].grams == 250.0


def test_multiple_items_with_grams():
    items = parse_caption("rice 200g, chicken 150g")
    assert [(i.name, i.grams) for i in items] == [("rice", 200.0), ("chicken", 150.0)]


def test_mixed_grams_and_no_grams():
    items = parse_caption("roti canai 95g, teh tarik")
    assert [(i.name, i.grams) for i in items] == [("roti canai", 95.0), ("teh tarik", None)]


def test_and_separator():
    items = parse_caption("nasi lemak and chicken rice")
    assert [i.name for i in items] == ["nasi lemak", "chicken rice"]


def test_kg_converted_to_grams():
    items = parse_caption("chicken rice 0.5kg")
    assert items[0].grams == 500.0


def test_grams_with_space_and_word_unit():
    items = parse_caption("char kway teow 350 grams")
    assert items[0].name == "char kway teow"
    assert items[0].grams == 350.0


def test_empty_and_none_captions():
    assert parse_caption(None) == []
    assert parse_caption("   ") == []
