import json
from lxml import etree
from lxml.etree import XMLParser

def recursive_json_nest(element, output):
    element_dict = {'@{}'.format(e_key): element.get(e_key) for e_key in element.keys()}
    if element.text is not None and element.text.strip()!='':
        element_dict['text()'] = element.text
    for e_child in element.getchildren():
        element_dict = recursive_json_nest(e_child, element_dict)
    if element.tag in output.keys():
        output[element.tag].append(element_dict)
    else:
        output[element.tag] = [element_dict]
    return output

def main(file_path):
    large_parser = XMLParser(huge_tree=True)
    root = etree.parse(file_path, parser=large_parser).getroot()
    output = recursive_json_nest(root, {})
    return output

if __name__ == '__main__':
    main('../data/sample.xml')
