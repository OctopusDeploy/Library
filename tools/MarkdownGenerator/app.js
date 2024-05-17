import path from 'node:path';
import * as fs from 'node:fs/promises';
import * as detail from './detail.js';
import { toSlug }  from './formatting.js';

const templatePath = '../../step-templates';
const distributionPath = '../../integrations';

const files = await fs.readdir(templatePath);
const categories = {};

await cleanOutputFolder();

for (let file of files) {
    const json = await getTemplateData(file);

    if (json == null) {
        continue;
    }

    const category = getSafeCategory(json);

    await createCategory(category);

    categories[category].templates.push({
        id: json.Id,
        name: json.Name
    });

    await createMarkdown(category, json, file);
}

console.log(categories);

async function cleanOutputFolder() {
    await fs.rmdir(distributionPath, { recursive: true });
}

async function getTemplateData(file) {
    const filePath = `${templatePath}/${file}`;
    const ext = path.extname(filePath);

    if (ext != '.json') {
        return null;
    }

    console.log(ext, filePath);

    const fileText = await fs.readFile(filePath, { encoding: 'utf8' });
    return JSON.parse(fileText);
}

function getSafeCategory(data) {
    const category = data.Category;
    if (category == null || category.length == 0) {
        console.warn(`There is no category for ${data.Name}. Using 'other'.`);
        return 'other';
    }

    return category.toLowerCase();
}

async function createCategory(category) {
    const categoryExists = categories[category] != null;

    if (categoryExists) {
        categories[category].count++;
    } else {
        categories[category] = { count: 1, templates: []}
    }

    await fs.mkdir(`${distributionPath}/${toSlug(category)}`, { recursive: true });
}

async function createMarkdown(category, data, file) {
    const content = detail.getContent(category, data, file);

    await fs.writeFile(`${distributionPath}/${toSlug(category)}/${toSlug(data.Name)}.md`, content)
}



