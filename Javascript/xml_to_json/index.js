const libxml = require("libxmljs2");
const fs = require("fs");

// def recursive_json_nest(element, output):
//     element_dict = {'@{}'.format(e_key): element.get(e_key) for e_key in element.keys()}
//     if element.text is not None and element.text.strip()!='':
//         element_dict['text()'] = element.text
//     for e_child in element.getchildren():
//         element_dict = recursive_json_nest(e_child, element_dict)
//     if element.tag in output.keys():
//         output[element.tag].append(element_dict)
//     else:
//         output[element.tag] = [element_dict]
//     return output
const recursiveJsonNest = (element, output) => {
  let elementName = element.name();
  if(elementName !== 'text'){
    let elementObj = {};
    element.attrs().forEach((attr) => {
      elementObj[`@${attr.name()}`] = attr.value();
    });
    const elementChildren = element.childNodes();
    elementChildren.forEach((child) => {
      elementObj = recursiveJsonNest(child, elementObj);
    });
    if(Object.keys(output).includes(elementName)){
      output[elementName].push(elementObj);
    } else {
      output[elementName] = [elementObj];
    };
  }else{
    output['text()'] = element.text();
  };
  
  return output;
}


const main = (filePath) => {
  const xml_text = fs.readFileSync(filePath, "utf-8");
  const root = libxml.parseXml(xml_text).root();
  const output = recursiveJsonNest(root, {});
  return output;
}


module.exports = {
  main: main,
};
