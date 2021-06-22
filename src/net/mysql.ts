import type mysql from 'mysql';
const mysqlm = (0||require)('mysql') as typeof mysql;


class MySQLProject {
    db: mysql.Connection
    schema: SchemaRef

    constructor(mysqlConfig: mysql.ConnectionConfig, schema: SchemaRef) {
        this.db = mysqlm.createConnection(mysqlConfig);
        this.schema = schema;
    }

    async connect() {
        if (this.db.state === 'disconnected')
            await new Promise<void>((resolve, reject) =>
                this.db.connect(err => err ? reject(err) : resolve()));
    }

    disconnect() {
        return new Promise(resolve => this.db.end(resolve));
    }

    query(q: string, values: any = []) {
        return new Promise((resolve, reject) =>
            this.db.query(q, values, (err, rows, fields) =>
                err ? reject(err) : resolve({rows, fields})));
    }
}

import SchemaRef = MySQLProject.SchemaRef;


namespace MySQLProject {
    export type TableRef = {
        table: string
        nameField: string
        contentField: string
    };

    export type SchemaRef = TableRef[];
}


export { MySQLProject }