import assert from 'assert';
import fs from 'fs';
import path from 'path';
import type mysql from 'mysql';
const mysqlm = (0||require)('mysql') as typeof mysql;


class MySQLProject {
    db: mysql.Connection
    schema: SchemaRef
    localWorkDir: string

    constructor(mysqlConfig: mysql.ConnectionConfig, schema: SchemaRef, localWorkDir?: string) {
        this.db = mysqlm.createConnection(mysqlConfig);
        this.schema = schema;
        this.localWorkDir = localWorkDir
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
        return new Promise<MySQLProject.QueryResult>((resolve, reject) =>
            this.db.query(q, values, (err, rows, fields) =>
                err ? reject(err) : resolve({rows, fields})));
    }

    async list() {
        var perTable = {};
        for (let t of this.schema) {
            var {rows} = await this.query(
                `SELECT ${t.nameField} FROM ${t.table} WHERE ${t.whereCond || 'TRUE'}`);
            perTable[t.table] = rows.map(row => row[t.nameField]);
        }
        return perTable;
    }

    async read(name: string) {
        var t = this.schema[0] /** @todo */,
            {rows} = await this.readRow(t, name);
        return rows[0]?.[t.contentField];
    }

    readRow(tableRef: TableRef, name: string) {
        var t = tableRef;
        return this.query(
            `SELECT * FROM ${t.table}  WHERE ${t.whereCond} AND ${t.nameField} = ?`,
            [name]);
    }

    write(name: string, content: string) {
        var t = this.schema[0]; /** @todo */
        return this.query(
            `UPDATE ${t.table} SET ${t.contentField} = ? WHERE ${t.whereCond} AND ${t.nameField} = ?`,
            [content, name]);
    }

    async pull(name: string) {
        var content = await this.read(name);
        fs.writeFileSync(this._localFilename(name), content);
    }

    push(name: string) {
        var content = fs.readFileSync(this._localFilename(name), 'utf-8');
        return this.write(name, content);
    }

    _localFilename(name: string) {
        assert(this.localWorkDir);
        var type = this.schema[0].type; /** @todo */
        return path.join(this.localWorkDir, type ? `${name}.${type}` : name);
    }
}

import SchemaRef = MySQLProject.SchemaRef;
import TableRef = MySQLProject.TableRef;


namespace MySQLProject {
    export type TableRef = {
        table: string
        nameField: string
        titleField: string
        contentField: string
        whereCond?: string
        type?: string
    };

    export type SchemaRef = TableRef[];

    export type QueryResult = {rows: any[], fields: any[]};
}


export { MySQLProject }