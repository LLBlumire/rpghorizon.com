const pluginRss = require("@11ty/eleventy-plugin-rss");
const anchors_plugin = require('@orchidjs/eleventy-plugin-ids');

module.exports = function (eleventyConfig) {
    eleventyConfig.addPassthroughCopy("./src/asset/");
    eleventyConfig.addWatchTarget("./src/asset");
    eleventyConfig.addPassthroughCopy({"./src/favicon/": "/"});
    eleventyConfig.addWatchTarget("./src/favicon");
    eleventyConfig.addPassthroughCopy("./src/css/");
    eleventyConfig.addWatchTarget("./src/css");
    eleventyConfig.addPlugin(pluginRss);
    eleventyConfig.addNunjucksFilter("limit", (arr, limit) => arr.slice(0, limit));
    eleventyConfig.addPlugin(anchors_plugin);
    return {
        dir: {
            input: "src"
        }
    }
}
