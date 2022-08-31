const libxml = require("libxmljs2");
const fs = require("fs");


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
