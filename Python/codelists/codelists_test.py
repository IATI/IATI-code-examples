from codelists import main
import pytest


@pytest.fixture(scope='module')
def sample_data():
    return main("../data/sample.json")


@pytest.fixture(autouse=True, scope='class')
def _request_sample_data(request, sample_data):
    request.cls._sample_data = sample_data


class TestCodelistMain:
    @pytest.mark.parametrize(
        ('x', 'y', 'data_type'),
        [
            ("country_budget_items_budget_item_code", "5.1.1", "list"),
            ("country_budget_items_budget_item_code_recode", "Health - policy, planning and administration", "list"),
            ("dataset_version", "2.03", "str"),
            ("dataset_version_recode", "2.03", "str"),
        ]
    )
    def test_sample_data_values(self, x, y, data_type):
        if data_type == "list":
            assert self._sample_data[0][x][0] == y
        else:
            assert self._sample_data[0][x] == y