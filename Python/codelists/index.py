from lxml import etree
import requests
import re
import json

# Set version to 2.03 and language to English
VERSION = "2.03"
LANGUAGE = "en"
STANDARD = "activity"

# A function to convert xpath names to Datastore field names
def convertNameToCanonical(xpath):
    retval = xpath.replace("//iati-activities/", "")
    retval = retval.replace("//iati-activity/", "")
    retval = retval.replace("//iati-organisations/", "")
    retval = retval.replace("//iati-organisation/", "")
    retval = retval.replace("//@", "")
    retval = retval.replace("/text()", "")
    if retval.startswith("@"):
        retval = retval[1:]
    retval = retval.replace("/@", "@")
    retval = retval.replace("-", "_")
    retval = retval.replace(":", "_")
    retval = retval.replace("/", "@")
    retval = retval.replace("@", "_")
    return retval


# A function to remove attributes from xpath
def stripAttributePath(xpath):
    split_xpath = xpath.split("/")
    if split_xpath[-1].startswith("@"):
        split_xpath = split_xpath[0:-1]
    return "/".join(split_xpath)


# A function to fetch parent xpaths
def parentPath(xpath, generations=1):
    split_xpath = xpath.split("/")
    split_xpath = split_xpath[0:(-1 * generations)]
    return "/".join(split_xpath)

def main():
    # Pull in codelist mapping in XML
    mapping_list = list()
    mapping_url = "https://raw.githubusercontent.com/IATI/IATI-Codelists/version-{}/mapping.xml".format(VERSION)
    mapping_content = requests.get(mapping_url)
    mapping_xml = etree.fromstring(mapping_content.text)
    mappings = mapping_xml.xpath("/mappings/mapping")
    for mapping in mappings:
        path = mapping.xpath("./path/text()")[0]
        if (
            STANDARD == "activity" and (
            path.startswith("//iati-activity") or path.startswith("//iati-activities") or path.startswith("//@xml:lang")
            )
        ) or (
            STANDARD == "organisation" and (
            path.startswith("//iati-organisation") or path.startswith("//iati-organisations") or path.startswith("//@xml:lang")
            )
        ):
            codelist = mapping.xpath("./codelist/@ref")[0]
            condition_nodes = mapping.xpath("./condition/text()")
            if len(condition_nodes) == 0:
                mapping_dict = {
                    "path": path,
                    "codelist": codelist,
                    "datastore_name": convertNameToCanonical(path)
                }
                if path == "//iati-activities/@version":
                    mapping_dict["datastore_name"] = "dataset_version" # Special case
                mapping_list.append(mapping_dict)
            else:
                condition = condition_nodes[0]
                condition_path = stripAttributePath(path)
                if condition.startswith(".."):
                    condition_path = parentPath(condition_path)
                conditions = condition.split(" or ")
                for condition in conditions:
                    condition_attribute = re.findall("@\\w+", condition)[0]
                    condition_value_match = re.findall("= '.+'", condition)
                    if len(condition_value_match) > 0:
                        condition_value = condition_value_match[0].replace("'", "").replace("= ", "")
                    else:
                        condition_value = ""
                    condition_path = "{}/{}".format(condition_path, condition_attribute)
                    mapping_dict = {
                        "path": path,
                        "codelist": codelist,
                        "datastore_name": convertNameToCanonical(path),
                        "condition_datastore_name": convertNameToCanonical(condition_path),
                        "condition_value": condition_value
                    }
                    if path == "//iati-activities/@version":
                        mapping_dict["datastore_name"] = "dataset_version" # Special case
                    mapping_list.append(mapping_dict)


    # Find unique codelists and download
    cl_list = list()
    unique_codelists = list(set([m["codelist"] for m in mapping_list]))
    for codelist in unique_codelists:
        codelist_url = "https://cdn.iatistandard.org/prod-iati-website/reference_downloads/{}/codelists/downloads/clv3/json/{}/{}.json".format(
            VERSION.replace(".",""),
            LANGUAGE,
            codelist
        )
        codelist_json = requests.get(codelist_url).json()["data"]
        for cl_d in codelist_json:
            cl_d["codelist"] = codelist
            if "name" not in cl_d.keys():
                cl_d["name"] = cl_d["code"]
            cl_list.append(cl_d)

    with open("../data/sample.json", "r") as sample_data_file:
        sample_data = json.load(sample_data_file)["response"]["docs"]
        for i in range(0, len(sample_data)):
            row = sample_data[i]
            field_names = list(row.keys())
            for field_name in field_names:
                new_field_name = "{}_recode".format(field_name)
                value_codes = row[field_name]
                if field_name in [mapping["datastore_name"] for mapping in mapping_list]:
                    mapping_subset = [mapping for mapping in mapping_list if mapping["datastore_name"] == field_name]
                    if len(mapping_subset) == 1 and "condition_datastore_name" not in mapping_subset[0].keys():
                        # Unconditional
                        codelist_subset = [codelist_item for codelist_item in cl_list if codelist_item["codelist"] == mapping_subset[0]["codelist"]]
                        codelist_subset.append({"code": "", "name": ""})
                        value_names = list()
                        if type(value_codes) is list:
                            for value_code in value_codes:
                                value_name_comp = [cl_item["name"] for cl_item in codelist_subset if cl_item["code"] == value_code]
                                if value_name_comp:
                                    value_names.append(value_name_comp[0])
                                else:
                                    value_names.append(value_code)
                        else:
                            value_name_comp = [cl_item["name"] for cl_item in codelist_subset if cl_item["code"] == value_codes]
                            if value_name_comp:
                                value_names = value_name_comp[0]
                            else:
                                value_names = value_code
                        sample_data[i][new_field_name] = value_names
                    else:
                        # Conditional
                        conditional_datastore_name = mapping_subset[0]["condition_datastore_name"]
                        try:
                            cond_compare_values = row[conditional_datastore_name]
                        except KeyError:
                            cond_compare_values = [""] * len(row[field_name])
                        for j in range(0, len(cond_compare_values)):
                            cond_compare_value = cond_compare_values[j]
                            mapping_subset = [mapping for mapping in mapping_subset if mapping["condition_value"] == cond_compare_value]
                            if len(mapping_subset) > 0: # No codelist for this value if 0
                                codelist_subset = [codelist_item for codelist_item in cl_list if codelist_item["codelist"] == mapping_subset[0]["codelist"]]
                                codelist_subset.append({"code": "", "name": ""})
                                value_code = row[field_name][j]
                                value_name_comp = [cl_item["name"] for cl_item in codelist_subset if cl_item["code"] == value_code]
                                if value_name_comp:
                                    value_name = value_name_comp[0]
                                else:
                                    value_name = value_code
                                    print("Warning: {} is not in codelist {}".format(value_code, mapping_subset[0]["codelist"]))
                                if new_field_name not in sample_data[i].keys():
                                    sample_data[i][new_field_name] = sample_data[i][field_name][:]
                                sample_data[i][new_field_name][j] = value_name
    return sample_data

if __name__ == '__main__':
    main()