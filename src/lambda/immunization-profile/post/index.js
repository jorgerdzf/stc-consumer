exports.handler = async (event) => {
    try {
        const response = await processHandler(event);
        return {
            statusCode: 200,
            headers: { 'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json' },
            body: JSON.stringify(response)
        }
    } catch (err) {
        return {
            headers: { 'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json' },
            statusCode: 500,
            body: JSON.stringify(err),
        }
    }
};
const processHandler = async (event) => {
    return { data: "ok" }
}