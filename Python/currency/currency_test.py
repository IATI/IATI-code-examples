from currency import main, fetch_field
import pytest


@pytest.fixture(scope='module')
def sample_currency_data():
    return main()


@pytest.fixture(autouse=True, scope='class')
def _request_sample_currency_data(request, sample_currency_data):
    request.cls._sample_currency_data = sample_currency_data


class TestCurrencyMain:
    @pytest.mark.parametrize(
        ('source', 'index', 'field_name', 'expected_value'),
        [
            ("transactions", 69, "transaction_value", 200000),
            ("transactions", 69, "transaction_value_usd", 286800),
            ("budgets", 29, "budget_value", 200000),
            ("budgets", 29, "budget_value_usd", 282940),
        ]
    )
    def test_sample_data_values(self, source, index, field_name, expected_value):
        assert fetch_field(self._sample_currency_data[source][index], field_name) == expected_value
