const codelist = require("./codelists/index");

(async () => {
    switch (process.argv[2]) {
        case 'codelists':
            console.log(await codelist(process.argv[3]));
            break;
        default:
            break;
    }
  
})();