from xml_to_json import main
import pytest


@pytest.fixture(scope='module')
def sample_json_data():
    return main('../data/sample.xml')


@pytest.fixture(autouse=True, scope='class')
def _request_sample_json_data(request, sample_json_data):
    request.cls._sample_json_data = sample_json_data


class TestXmlToJsonMain:
    @pytest.mark.parametrize(
        ('element_key1', 'element_key2', 'expected_value'),
        [
            ('iati-identifier', 'text()', 'DAC-1601-INV-003731'),
            ('default-flow-type', '@code', '30')
        ]
    )
    def test_sample_data_values(self, element_key1, element_key2, expected_value):
        assert self._sample_json_data['iati-activities'][0]['iati-activity'][0][element_key1][0][element_key2] == expected_value